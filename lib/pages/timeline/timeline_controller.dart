import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  bool notShowAbandonedBangumis = false;

  @observable
  bool notShowWatchedBangumis = false;

  int sortType = 1;

  late DateTime selectedDate;

  void init() {
    selectedDate = DateTime.now();
    seasonString = AnimeSeason(selectedDate).toString();
    getSchedules();
  }

  Future<void> getSchedules() async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final resBangumiCalendar = await BangumiHTTP.getCalendar();
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
    changeSortType(sortType);
    isLoading = false;
    isTimeOut = bangumiCalendar.isEmpty;
  }

  Future<void> getSchedulesBySeason() async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final resBangumiCalendar = await _fetchSeasonCalendar(selectedDate);
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
    isLoading = false;
    if (bangumiCalendar.isEmpty) {
      isTimeOut = true;
    } else {
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
    }
    if (!isTimeOut) {
      changeSortType(sortType);
    }
  }

  Future<void> getSchedulesBySeasons(List<DateTime> seasonDates) async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final normalized = <String, DateTime>{};
    for (final date in seasonDates) {
      final key = '${date.year}-${date.month}';
      normalized[key] = date;
    }
    if (normalized.isEmpty) {
      isLoading = false;
      isTimeOut = true;
      return;
    }
    final merged = List.generate(7, (_) => <BangumiItem>[]);
    final seenByDay = List.generate(7, (_) => <int>{});
    for (final seasonDate in normalized.values) {
      final seasonCalendar = await _fetchSeasonCalendar(seasonDate);
      for (int i = 0; i < 7; i++) {
        for (final item in seasonCalendar[i]) {
          if (seenByDay[i].add(item.id)) {
            merged[i].add(item);
          }
        }
      }
    }
    bangumiCalendar.addAll(merged);
    isLoading = false;
    if (bangumiCalendar.isEmpty) {
      isTimeOut = true;
    } else {
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
    }
    if (!isTimeOut) {
      changeSortType(sortType);
    }
  }

  void tryEnterSeason(DateTime date) {
    selectedDate = date;
    seasonString = "加载中 ٩(◦`꒳´◦)۶";
  }

  Future<List<List<BangumiItem>>> _fetchSeasonCalendar(DateTime date) async {
    // 4次获取，每次最多20部
    var time = 0;
    const maxTime = 4;
    const limit = 20;
    final resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (time = 0; time < maxTime; time++) {
      final offset = time * limit;
      final newList = await BangumiHTTP.getCalendarBySearch(
          AnimeSeason(date).toSeasonStartAndEnd(), limit, offset);
      for (int i = 0; i < resBangumiCalendar.length; ++i) {
        resBangumiCalendar[i].addAll(newList[i]);
      }
    }
    return resBangumiCalendar;
  }

  /// 排序方式
  /// 1. default
  /// 2. score
  /// 3. heat
  void changeSortType(int type) {
    if (type < 1 || type > 3) {
      return;
    }
    sortType = type;
    var resBangumiCalendar = bangumiCalendar.toList();
    for (var dayList in resBangumiCalendar) {
      switch (sortType) {
        case 1:
          dayList.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 2:
          dayList.sort((a, b) => (b.ratingScore).compareTo(a.ratingScore));
          break;
        case 3:
          dayList.sort((a, b) => (b.votes).compareTo(a.votes));
          break;
        default:
      }
    }
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
  }

  @action
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
  }

  @action
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
  }

  Set<int> loadAbandonedBangumiIds() {
    return <int>{};
  }

  Set<int> loadWatchedBangumiIds() {
    return <int>{};
  }
}
