import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

part 'collect_module.g.dart';

@HiveType(typeId: 3)
class CollectedBangumi {
  @HiveField(0)
  BangumiItem bangumiItem;

  @HiveField(1)
  DateTime time;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  @HiveField(2)
  int type;

  // 支持一个番剧位于多个收藏夹内
  @HiveField(3)
  List<int> types;

  String get key => bangumiItem.id.toString();

  CollectedBangumi(this.bangumiItem, this.time, this.type,
      [List<int>? initialTypes])
      : types = _normalizeTypes(initialTypes ?? <int>[type]) {
    final normalized = _normalizeTypes(types);
    setTypes(normalized);
  }

  static String getKey(BangumiItem bangumiItem) => bangumiItem.id.toString();

  List<int> get effectiveTypes {
    final normalized = _normalizeTypes(types);
    if (normalized.isNotEmpty) return normalized;
    return _normalizeTypes(<int>[type]);
  }

  bool containsType(int value) => effectiveTypes.contains(value);

  bool get isCollected => effectiveTypes.isNotEmpty;

  void setTypes(List<int> values) {
    final normalized = _normalizeTypes(values);
    types = normalized;
    type = normalized.isEmpty ? 0 : normalized.first;
  }

  void addType(int value) {
    if (value < 1) return;
    final nextTypes = List<int>.from(effectiveTypes);
    if (!nextTypes.contains(value)) {
      nextTypes.add(value);
    }
    setTypes(nextTypes);
  }

  void removeType(int value) {
    final nextTypes = List<int>.from(effectiveTypes)
      ..removeWhere((item) => item == value);
    setTypes(nextTypes);
  }

  static List<int> _normalizeTypes(List<int> values) {
    final result = <int>[];
    final seen = <int>{};
    for (final value in values) {
      if (value < 1) continue;
      if (seen.add(value)) {
        result.add(value);
      }
    }
    return result;
  }

  @override
  String toString() {
    return 'types: ${effectiveTypes.join(",")}, time: $time, anime: ${bangumiItem.name}';
  }
}
