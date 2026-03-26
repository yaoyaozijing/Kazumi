import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/bean/widget/collect_filter_panel.dart';
import 'package:kazumi/bean/widget/sort_filter_tab_panel.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/selection_state_overlay.dart';
import 'package:kazumi/bean/widget/two_pane_layout.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  final TimelineController timelineController =
      Modular.get<TimelineController>();
  final CollectController collectController = Modular.get<CollectController>();
  late NavigationBarState navigationBarState;
  TabController? tabController;
  late bool showRating;

  Set<int> selectedFilterIds = <int>{};
  Set<DateTime> selectedSeasonDates = <DateTime>{};
  final Set<int> selectedBangumiIds = <int>{};
  bool get hideBuiltInCollectFolders =>
      GStorage.setting.get(
        SettingBoxKey.collectHideBuiltInFolders,
        defaultValue: false,
      ) ==
      true;
  List<CollectFolder> get visibleCollectFolders => hideBuiltInCollectFolders
      ? collectController
          .getCollectFolders()
          .where((folder) => !folder.isBuiltIn)
          .toList()
      : collectController.getCollectFolders();
  bool get foldableOptimization =>
      GStorage.setting.get(
        SettingBoxKey.foldableOptimization,
        defaultValue: false,
      ) ==
      true;
  String get collectGridStyle {
    final value = GStorage.setting.get(SettingBoxKey.timelineGridStyle);
    if (value is String &&
        (value == 'compact' ||
            value == 'loose' ||
            value == 'detailed' ||
            value == 'list')) {
      return value;
    }
    return 'detailed';
  }

  bool get useCompactGrid => collectGridStyle == 'compact';
  bool get useDetailedGrid => collectGridStyle == 'detailed';
  bool get useListGrid => collectGridStyle == 'list';

  bool get isSelectionMode => selectedBangumiIds.isNotEmpty;

  bool _isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= TwoPaneDefaults.minWidth;

  bool _isInInfoDetail() => Modular.to.path.startsWith('/tab/timeline/info');

  List<BangumiItem> get selectedBangumiItems {
    final unique = <int, BangumiItem>{};
    for (final day in timelineController.bangumiCalendar) {
      for (final item in day) {
        if (selectedBangumiIds.contains(item.id)) {
          unique[item.id] = item;
        }
      }
    }
    return unique.values.toList();
  }

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    tabController =
        TabController(vsync: this, length: tabs.length, initialIndex: weekday);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    showRating =
        GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true);
    selectedFilterIds = getAllFilterIds();
    if (timelineController.bangumiCalendar.isEmpty) {
      timelineController.init();
    }
    selectedSeasonDates = {normalizeSeasonStart(DateTime.now())};
    Modular.to.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    Modular.to.removeListener(_handleRouteChange);
    navigationBarState.showNavigate();
    tabController?.dispose();
    super.dispose();
  }

  void _handleRouteChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncNavigationWithLeftPaneVisibility(bool isVisible) {
    if (!mounted) return;
    if (isVisible) {
      navigationBarState.showNavigate();
    } else {
      navigationBarState.hideNavigate();
    }
  }

  void _openInfo(BangumiItem item) {
    final route = '/tab/timeline/info/?bangumiId=${item.id}';
    Modular.to.navigate(route, arguments: item);
  }

  void onBackPressed(BuildContext context) {
    if (isSelectionMode) {
      setState(() {
        selectedBangumiIds.clear();
      });
      return;
    }
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (_isInInfoDetail()) {
      Modular.to.navigate('/tab/timeline/');
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  DateTime generateDateTime(int year, String season) {
    switch (season) {
      case '冬':
        return DateTime(year, 1, 1);
      case '春':
        return DateTime(year, 4, 1);
      case '夏':
        return DateTime(year, 7, 1);
      case '秋':
        return DateTime(year, 10, 1);
      default:
        return DateTime.now();
    }
  }

  final List<Tab> tabs = const <Tab>[
    Tab(text: '一'),
    Tab(text: '二'),
    Tab(text: '三'),
    Tab(text: '四'),
    Tab(text: '五'),
    Tab(text: '六'),
    Tab(text: '日'),
  ];

  final seasons = ['秋', '夏', '春', '冬'];

  String getStringByDateTime(DateTime d) {
    return d.year.toString() + Utils.getSeasonStringByMonth(d.month);
  }

  DateTime normalizeSeasonStart(DateTime d) {
    final season = Utils.getSeasonStringByMonth(d.month);
    return generateDateTime(d.year, season);
  }

  String buildSeasonSummary(Set<DateTime> seasonDates) {
    if (seasonDates.length <= 1) {
      return AnimeSeason(timelineController.selectedDate).toString();
    }
    final sorted = seasonDates.toList()..sort((a, b) => b.compareTo(a));
    final first = sorted.first;
    final firstLabel =
        '${first.year}${Utils.getSeasonStringByMonth(first.month)}';
    return '$firstLabel 等${sorted.length}季';
  }

  void showSeasonBottomSheet(BuildContext context) {
    final currDate = DateTime.now();
    final years = List.generate(20, (index) => currDate.year - index);

    // 按年份分组生成可用季节
    Map<int, List<DateTime>> yearSeasons = {};
    for (final year in years) {
      List<DateTime> availableSeasons = [];
      for (final season in seasons) {
        final date = generateDateTime(year, season);
        if (currDate.isAfter(date)) {
          availableSeasons.add(date);
        }
      }
      if (availableSeasons.isNotEmpty) {
        yearSeasons[year] = availableSeasons;
      }
    }

    KazumiDialog.showBottomSheet(
      // context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        final tempSelected = <DateTime>{
          normalizeSeasonStart(timelineController.selectedDate)
        };
        bool isMultiMode = false;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(builder: (context, setSheetState) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '时间机器',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const Spacer(),
                          if (isMultiMode)
                            IconButton(
                              tooltip: '保存所选',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                if (tempSelected.isEmpty) {
                                  KazumiDialog.showToast(message: '请至少选择一个季度');
                                  return;
                                }
                                setState(() {
                                  selectedSeasonDates =
                                      Set<DateTime>.from(tempSelected);
                                });
                                Navigator.pop(context);
                                reloadSelectedSeasons();
                              },
                              icon: const Icon(Icons.save_outlined),
                            ),
                          if (isMultiMode) const SizedBox(width: 8),
                          IconButton(
                            tooltip: isMultiMode ? '切换为单选' : '切换为多选',
                            style: IconButton.styleFrom(
                              backgroundColor: isMultiMode
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                  : Colors.transparent,
                              foregroundColor: isMultiMode
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            onPressed: () {
                              setSheetState(() {
                                isMultiMode = !isMultiMode;
                                if (!isMultiMode && tempSelected.isNotEmpty) {
                                  final latest = tempSelected.toList()
                                    ..sort((a, b) => b.compareTo(a));
                                  tempSelected
                                    ..clear()
                                    ..add(latest.first);
                                }
                              });
                            },
                            icon: const Icon(Icons.checklist_rtl),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        itemCount: yearSeasons.keys.length,
                        itemBuilder: (context, index) {
                          final year = yearSeasons.keys.elementAt(index);
                          final availableSeasons = yearSeasons[year]!;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$year年',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                buildSeasonSegmentedButton(
                                  context,
                                  availableSeasons,
                                  tempSelected,
                                  isMultiMode: isMultiMode,
                                  setSheetState: setSheetState,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            });
          },
        );
      },
    );
  }

  Widget buildSeasonSegmentedButton(BuildContext context,
      List<DateTime> availableSeasons, Set<DateTime> tempSelected,
      {required bool isMultiMode,
      required void Function(VoidCallback fn) setSheetState}) {
    final selectedForYear = availableSeasons
        .where(
            (season) => tempSelected.any((d) => Utils.isSameSeason(d, season)))
        .toSet();

    final segments = availableSeasons.map((date) {
      final seasonName = Utils.getSeasonStringByMonth(date.month);
      return ButtonSegment<DateTime>(
        value: date,
        label: Text(
          seasonName,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        icon: getSeasonIcon(seasonName),
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DateTime>(
        segments: segments,
        selected: selectedForYear,
        onSelectionChanged: (Set<DateTime> newSelection) {
          if (!isMultiMode) {
            if (newSelection.isEmpty) return;
            final selected = normalizeSeasonStart(newSelection.first);
            setState(() {
              selectedSeasonDates = {selected};
            });
            Navigator.pop(context);
            reloadSelectedSeasons();
            return;
          }
          setSheetState(() {
            for (final season in availableSeasons) {
              tempSelected.removeWhere((d) => Utils.isSameSeason(d, season));
            }
            for (final season in newSelection) {
              tempSelected.add(normalizeSeasonStart(season));
            }
          });
        },
        multiSelectionEnabled: isMultiMode,
        showSelectedIcon: false,
        emptySelectionAllowed: true,
        style: SegmentedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedForegroundColor:
              Theme.of(context).colorScheme.onSecondaryContainer,
          selectedBackgroundColor:
              Theme.of(context).colorScheme.secondaryContainer,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget getSeasonIcon(String seasonName) {
    IconData iconData;
    switch (seasonName) {
      case '春':
        iconData = Icons.eco;
        break;
      case '夏':
        iconData = Icons.wb_sunny;
        break;
      case '秋':
        iconData = Icons.park;
        break;
      case '冬':
        iconData = Icons.ac_unit;
        break;
      default:
        iconData = Icons.schedule;
    }

    return Icon(
      iconData,
      size: 18,
    );
  }

  void onSeasonSelected(DateTime date) async {
    final currDate = DateTime.now();
    timelineController.tryEnterSeason(date);

    if (Utils.isSameSeason(timelineController.selectedDate, currDate)) {
      await timelineController.getSchedules();
    } else {
      await timelineController.getSchedulesBySeason();
    }

    timelineController.seasonString =
        AnimeSeason(timelineController.selectedDate).toString();
  }

  Future<void> reloadSelectedSeasons() async {
    final selected = selectedSeasonDates.isEmpty
        ? <DateTime>[normalizeSeasonStart(DateTime.now())]
        : selectedSeasonDates.toList();
    timelineController.tryEnterSeason(selected.first);
    timelineController.seasonString = "加载中 ٩(◦`꒳´◦)۶";
    await timelineController.getSchedulesBySeasons(selected);
    timelineController.seasonString = buildSeasonSummary(selected.toSet());
  }

  Set<int> getAllFilterIds() =>
      <int>{0, ...visibleCollectFolders.map((folder) => folder.id)};

  Widget showTimelineOptionPanel() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final groups = collectController.getCollectGroups();
        final folders = visibleCollectFolders;
        return SortFilterTabPanel(
          sortChild: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(
                  value: 1,
                  label: Text('时间'),
                  icon: Icon(Icons.schedule, size: 18),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text('评分'),
                  icon: Icon(Icons.star_outline, size: 18),
                ),
                ButtonSegment<int>(
                  value: 3,
                  label: Text('热度'),
                  icon: Icon(Icons.local_fire_department_outlined, size: 18),
                ),
              ],
              selected: {timelineController.sortType},
              onSelectionChanged: (selected) {
                timelineController.changeSortType(selected.first);
                setSheetState(() {});
              },
            ),
          ),
          filterChild: CollectFilterPanel(
            groups: groups,
            folders: folders,
            selectedIds: selectedFilterIds,
            onChanged: (next) {
              setSheetState(() {
                selectedFilterIds = Set<int>.from(next);
              });
              setState(() {});
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTwoPane = _isTwoPane(context);
    final isInDetail = _isInInfoDetail();
    final shouldShowFilterFab = !isSelectionMode;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: null,
        body: TwoPaneLayout(
          isTwoPane: isTwoPane,
          isInDetail: isInDetail,
          foldableOptimization: foldableOptimization,
          onLeftPaneVisibilityChanged: _syncNavigationWithLeftPaneVisibility,
          leftPaneBuilder: (context, leftWidth, isTwoPane) => _buildLeftPane(
            availableWidth: leftWidth,
            isTwoPane: isTwoPane,
            shouldShowFilterFab: shouldShowFilterFab,
          ),
          rightPaneBuilder: (context, _, isTwoPane) =>
              _buildDetailPane(isTwoPane),
        ),
      ),
    );
  }

  Widget _buildLeftPane({
    required double availableWidth,
    required bool isTwoPane,
    required bool shouldShowFilterFab,
  }) {
    final timelineContent = _buildTimelineContent(availableWidth);
    return SafeArea(
      top: true,
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              _buildLeftTopBar(),
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: tabController,
                  tabs: tabs,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Divider(height: 1),
              Expanded(child: timelineContent),
            ],
          ),
          if (shouldShowFilterFab)
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildFilterFab(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(bool isTwoPane) {
    return SafeArea(
      top: isTwoPane,
      bottom: false,
      child: const RouterOutlet(),
    );
  }

  Widget _buildFilterFab() {
    return FloatingActionButton(
      onPressed: () async {
        KazumiDialog.showBottomSheet(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          isScrollControlled: true,
          context: context,
          builder: (context) {
            return showTimelineOptionPanel();
          },
        );
      },
      child: const Icon(Icons.tune),
    );
  }

  Widget _buildSeasonTitle() {
    final theme = Theme.of(context);
    final titleStyle =
        theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    return Tooltip(
      message: '点击打开时间机器',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Observer(
          builder: (context) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  timelineController.seasonString,
                  style: titleStyle,
                ),
              ],
            );
          },
        ),
        onTap: () {
          showSeasonBottomSheet(context);
        },
      ),
    );
  }

  Widget _buildLeftTopBar() {
    final hideDesktopCloseButton = _isTwoPane(context) && _isInInfoDetail();
    return SizedBox(
      height: kToolbarHeight,
      child: SysAppBar(
        needTopOffset: false,
        toolbarHeight: kToolbarHeight,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        showDesktopCloseButton: !hideDesktopCloseButton,
        title: _buildSeasonTitle(),
        actions: buildAppBarActions(),
      ),
    );
  }

  Widget _buildTimelineContent(double availableWidth) {
    if (timelineController.isLoading &&
        timelineController.bangumiCalendar.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (timelineController.isTimeOut) {
      return Center(
        child: SizedBox(
          height: 400,
          child: GeneralErrorWidget(errMsg: '什么都没有找到 (´;ω;`)', actions: [
            GeneralErrorButton(
              onPressed: () {
                reloadSelectedSeasons();
              },
              text: '点击重试',
            ),
          ]),
        ),
      );
    }
    return TabBarView(
      controller: tabController,
      children: contentGrid(timelineController.bangumiCalendar, availableWidth),
    );
  }

  List<Widget> contentGrid(
      List<List<BangumiItem>> bangumiCalendar, double availableWidth) {
    List<Widget> gridViewList = [];
    final int crossCount = Utils.getGridCrossCount(
      availableWidth: availableWidth,
      useDetailedGrid: useDetailedGrid,
      useListGrid: useListGrid,
    );
    final double detailedCardHeight =
        Utils.isDesktop() ? 160 : (Utils.isTablet() ? 140 : 120);
    const double gridPaddingHorizontal =
        StyleString.cardSpace * 2 + 16; // 外层左右 padding + EdgeInsets.all(8)
    final double gridMainAxisExtent = useDetailedGrid
        ? detailedCardHeight
        : useListGrid
            ? BangumiCardList.singleLineHeight
            : (() {
                final cardWidth = (availableWidth -
                        gridPaddingHorizontal -
                        (crossCount - 1) * StyleString.cardSpace) /
                    crossCount;
                return useCompactGrid
                    ? cardWidth / StyleString.bangumiCoverAspectRatio
                    : cardWidth / StyleString.bangumiCoverAspectRatio +
                        MediaQuery.textScalerOf(context).scale(45.0);
              })();
    for (var bangumiList in bangumiCalendar) {
      final filteredList = selectedFilterIds.isEmpty
          ? <BangumiItem>[]
          : bangumiList.where((item) {
              final types = collectController.getCollectTypes(item);
              if (types.isEmpty) {
                return selectedFilterIds.contains(0);
              }
              return types.any(selectedFilterIds.contains);
            }).toList();

      gridViewList.add(
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                StyleString.cardSpace,
                0,
                StyleString.cardSpace,
                0,
              ),
              sliver: SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    mainAxisSpacing: StyleString.cardSpace - 2,
                    crossAxisSpacing: StyleString.cardSpace,
                    crossAxisCount: crossCount,
                    mainAxisExtent: gridMainAxisExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (filteredList.isEmpty) return null;
                      final item = filteredList[index];
                      final isSelected = selectedBangumiIds.contains(item.id);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () {
                          toggleSelection(item.id, forceSelect: true);
                        },
                        onTap: isSelectionMode
                            ? () {
                                toggleSelection(item.id);
                              }
                            : null,
                        child: Stack(
                          children: [
                            IgnorePointer(
                              ignoring: isSelectionMode,
                              child: useDetailedGrid
                                  ? BangumiTimelineCard(
                                      bangumiItem: item,
                                      cardHeight: gridMainAxisExtent,
                                      showRating: showRating,
                                      onTap: () {
                                        _openInfo(item);
                                      },
                                    )
                                  : useListGrid
                                      ? BangumiCardList(
                                          bangumiItem: item,
                                          itemHeight: gridMainAxisExtent,
                                          showRating: showRating,
                                          onTap: () {
                                            _openInfo(item);
                                          },
                                        )
                                      : useCompactGrid
                                          ? BangumiCardCompact(
                                              bangumiItem: item,
                                              onTap: () {
                                                _openInfo(item);
                                              },
                                            )
                                          : BangumiCardV(
                                              bangumiItem: item,
                                              onTap: () {
                                                _openInfo(item);
                                              },
                                            ),
                            ),
                            SelectionStateOverlay(
                              isSelectionMode: isSelectionMode,
                              isSelected: isSelected,
                              borderRadius: 12,
                            ),
                          ],
                        ),
                      );
                    },
                    childCount:
                        filteredList.isNotEmpty ? filteredList.length : 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return gridViewList;
  }

  List<Widget> buildAppBarActions() {
    final actions = <Widget>[
      if (isSelectionMode)
        IconButton(
          tooltip: '添加到收藏夹',
          icon: const Icon(Icons.favorite),
          onPressed: addSelectedToCollectFolders,
        ),
      _buildGridStyleMenuButton(),
      const SizedBox(width: 4),
    ];
    return actions;
  }

  IconButton _buildGridStyleMenuButton() {
    return IconButton(
      tooltip: '切换视图样式',
      onPressed: _cycleGridStyle,
      icon: const Icon(Icons.view_module_outlined),
    );
  }

  Future<void> _cycleGridStyle() async {
    const styles = <String>['loose', 'compact', 'detailed', 'list'];
    final currentIndex = styles.indexOf(collectGridStyle);
    final nextIndex =
        currentIndex == -1 ? 0 : (currentIndex + 1) % styles.length;
    await GStorage.setting
        .put(SettingBoxKey.timelineGridStyle, styles[nextIndex]);
    if (!mounted) return;
    setState(() {});
  }

  void toggleSelection(int bangumiId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        selectedBangumiIds.add(bangumiId);
        return;
      }
      if (selectedBangumiIds.contains(bangumiId)) {
        selectedBangumiIds.remove(bangumiId);
      } else {
        selectedBangumiIds.add(bangumiId);
      }
    });
  }

  Future<void> addSelectedToCollectFolders() async {
    final items = selectedBangumiItems;
    if (items.isEmpty) {
      setState(() {
        selectedBangumiIds.clear();
      });
      return;
    }
    await showCollectFolderSelectionForItems(items);
  }

  Future<void> showCollectFolderSelectionForItems(
      List<BangumiItem> selectedItems) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return CollectFolderMultiSelectionSheet(
          collectController: collectController,
          items: selectedItems,
          folders: visibleCollectFolders,
          groups: collectController.getCollectGroups(),
          onStateChanged: () {
            if (!mounted) return;
            setState(() {});
          },
        );
      },
    );
  }
}
