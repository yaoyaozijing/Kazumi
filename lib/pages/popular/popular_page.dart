import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/custom_dropdown_menu.dart';
import 'package:kazumi/bean/widget/selection_state_overlay.dart';
import 'package:kazumi/bean/widget/two_pane_layout.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final PopularController popularController = Modular.get<PopularController>();
  final CollectController collectController = Modular.get<CollectController>();
  late NavigationBarState navigationBarState;
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
    final value = GStorage.setting.get(SettingBoxKey.popularGridStyle);
    if (value is String &&
        (value == 'compact' ||
            value == 'loose' ||
            value == 'detailed' ||
            value == 'list')) {
      return value;
    }
    return 'loose';
  }

  bool get useCompactGrid => collectGridStyle == 'compact';
  bool get useDetailedGrid => collectGridStyle == 'detailed';
  bool get useListGrid => collectGridStyle == 'list';
  bool get showRating =>
      GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true) ==
      true;

  // Key used to position the dropdown menu for the tag selector
  final GlobalKey selectorKey = GlobalKey();

  bool get isSelectionMode => selectedBangumiIds.isNotEmpty;

  bool _isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= TwoPaneDefaults.minWidth;

  bool _isInInfoDetail() => Modular.to.path.startsWith('/tab/popular/info');

  bool _shouldReserveDesktopOverlaySpace() {
    if (!Utils.isDesktop()) {
      return false;
    }
    final useSystemTitleBar = GStorage.setting.get(
          SettingBoxKey.showWindowButton,
          defaultValue: false,
        ) ==
        true;
    if (useSystemTitleBar) {
      return false;
    }
    // Keep the same behavior as the old close button:
    // reserve only on full-width (non-detail) page.
    return !_isInInfoDetail();
  }

  List<BangumiItem> get selectedBangumiItems {
    final unique = <int, BangumiItem>{};
    for (final item in popularController.trendList) {
      if (selectedBangumiIds.contains(item.id)) unique[item.id] = item;
    }
    for (final item in popularController.bangumiList) {
      if (selectedBangumiIds.contains(item.id)) unique[item.id] = item;
    }
    return unique.values.toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    if (popularController.trendList.isEmpty) {
      popularController.queryBangumiByTrend();
    }
    Modular.to.addListener(_handleRouteChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    scrollController.removeListener(scrollListener);
    navigationBarState.showNavigate();
    Modular.to.removeListener(_handleRouteChange);
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
    final route = '/tab/popular/info/?bangumiId=${item.id}';
    Modular.to.navigate(route, arguments: item);
  }

  void scrollListener() {
    popularController.scrollOffset = scrollController.offset;
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !popularController.isLoadingMore) {
      KazumiLogger()
          .i('PopularPageController: Fetching next recommendation batch');
      if (popularController.currentTag != '') {
        popularController.queryBangumiByTag();
      } else {
        popularController.queryBangumiByTrend();
      }
    }
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
      Modular.to.navigate('/tab/popular/');
      return;
    }
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      _lastPressedAt = DateTime.now();
      KazumiDialog.showToast(message: "再按一次退出应用", context: context);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isTwoPane = _isTwoPane(context);
    final isInDetail = _isInInfoDetail();
    final shouldShowScrollTopFab = !isSelectionMode;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        body: TwoPaneLayout(
          isTwoPane: isTwoPane,
          isInDetail: isInDetail,
          foldableOptimization: foldableOptimization,
          onLeftPaneVisibilityChanged: _syncNavigationWithLeftPaneVisibility,
          leftPaneBuilder: (context, _, isTwoPane) => _buildLeftPane(
            isTwoPane: isTwoPane,
            shouldShowScrollTopFab: shouldShowScrollTopFab,
          ),
          rightPaneBuilder: (context, _, isTwoPane) =>
              _buildDetailPane(isTwoPane),
        ),
      ),
    );
  }

  Widget _buildPopularContent(double availableWidth) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        buildSliverAppBar(),
        SliverToBoxAdapter(
          child: AnimatedOpacity(
            opacity: popularController.isLoadingMore ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: popularController.isLoadingMore
                ? const LinearProgressIndicator(minHeight: 4)
                : const SizedBox(height: 4),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              StyleString.cardSpace, 0, StyleString.cardSpace, 0),
          sliver: Builder(
            builder: (_) {
              if (popularController.isTimeOut) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: '什么都没有找到 (´;ω;`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            if (popularController.trendList.isEmpty) {
                              popularController.queryBangumiByTrend();
                            } else {
                              popularController.queryBangumiByTag();
                            }
                          },
                          text: '点击重试',
                        ),
                      ],
                    ),
                  ),
                );
              }
              return contentGrid(
                (popularController.currentTag == '')
                    ? popularController.trendList
                    : popularController.bangumiList,
                availableWidth,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPane({
    required bool isTwoPane,
    required bool shouldShowScrollTopFab,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mainContent = _buildPopularContent(constraints.maxWidth);
        return SafeArea(
          top: isTwoPane,
          bottom: false,
          child: Stack(
            children: [
              mainContent,
              if (shouldShowScrollTopFab)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildScrollTopFab(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailPane(bool isTwoPane) {
    return SafeArea(
      top: isTwoPane,
      bottom: false,
      child: const RouterOutlet(),
    );
  }

  Widget _buildScrollTopFab() {
    return FloatingActionButton(
      onPressed: () => scrollController.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
      child: const Icon(Icons.arrow_upward),
    );
  }

  Widget contentGrid(List<BangumiItem> bangumiList, double availableWidth) {
    final int crossCount = Utils.getGridCrossCount(
      availableWidth: availableWidth,
      useDetailedGrid: useDetailedGrid,
      useListGrid: useListGrid,
    );
    const double gridPaddingHorizontal =
        StyleString.cardSpace * 2 + 16; // 外层左右 padding + EdgeInsets.all(8)
    final double mainAxisExtent = useDetailedGrid
        ? (Utils.isDesktop() ? 160 : (Utils.isTablet() ? 140 : 120))
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
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // 行间距
          mainAxisSpacing: StyleString.cardSpace - 2,
          // 列间距
          crossAxisSpacing: StyleString.cardSpace,
          // 列数
          crossAxisCount: crossCount,
          mainAxisExtent: mainAxisExtent,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (bangumiList.isEmpty) return null;
            final item = bangumiList[index];
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
                            cardHeight: mainAxisExtent,
                            showRating: showRating,
                            onTap: () {
                              _openInfo(item);
                            },
                          )
                        : useListGrid
                            ? BangumiCardList(
                                bangumiItem: item,
                                itemHeight: mainAxisExtent,
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
          childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
        ),
      ),
    );
  }

  Widget buildSliverAppBar() {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 120,
      elevation: 0,
      titleSpacing: 0,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: buildActions(),
      title: null,
      flexibleSpace: SafeArea(
        child: dtb.DragToMoveArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxExtent = 120 - MediaQuery.of(context).padding.top;
              final t = (1 -
                  ((constraints.maxHeight - kToolbarHeight) /
                          (maxExtent - kToolbarHeight))
                      .clamp(0.0, 1.0));
              // 字重收缩后为 w500，展开时为 w700
              final fontWeight = t < 0.5 ? FontWeight.w700 : FontWeight.w500;
              final fontSize = lerpDouble(28, 20, t)!;
              return Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, top: 8, bottom: 8, right: 60),
                  child: SizedBox(
                    height: 44,
                    child: Observer(
                      builder: (_) {
                        final bool isTrend = popularController.currentTag == '';
                        return InkWell(
                          key: selectorKey,
                          borderRadius: BorderRadius.circular(8),
                          onTap: showTagMenu,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isTrend ? '热门番组' : popularController.currentTag,
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  fontWeight: fontWeight,
                                  fontSize: fontSize,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down,
                                  size: fontSize, color: theme.iconTheme.color),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> buildActions() {
    final forceBottom = GStorage.setting.get(
          SettingBoxKey.foldableOptimization,
          defaultValue: false,
        ) ==
        true;
    final bool useSideByLegacyRule =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bool useSideByWidthRule =
        MediaQuery.sizeOf(context).width >= TwoPaneDefaults.minWidth;
    final bool useSide = useSideByLegacyRule || useSideByWidthRule;
    final bool showSearchAction = forceBottom || !useSide;
    final actions = <Widget>[
      if (isSelectionMode)
        IconButton(
          tooltip: '添加到收藏夹',
          onPressed: addSelectedToCollectFolders,
          icon: const Icon(Icons.favorite),
        ),
      if (showSearchAction)
        IconButton(
          tooltip: '搜索',
          onPressed: () => Modular.to.pushNamed('/tab/search/'),
          icon: const Icon(Icons.search),
        ),
      _buildGridStyleMenuButton(),
      SizedBox(width: _shouldReserveDesktopOverlaySpace() ? 168 : 8),
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
        .put(SettingBoxKey.popularGridStyle, styles[nextIndex]);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> showTagMenu() async {
    // Calculate the position of the button manually to position the dropdown menu.
    // Using CustomDropdownMenu instead of PopupMenuButton to avoid flickering issues
    // and to support different font sizes in the button and menu items.
    final RenderBox renderBox =
        selectorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final selected = await Navigator.push<String>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomDropdownMenu(
            offset: offset,
            buttonSize: size,
            animation: animation,
            maxWidth: 80,
            items: [
              '',
              ...defaultAnimeTags,
            ],
            itemBuilder: (item) => item.isEmpty ? '热门番组' : item,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (selected == null) return;
    if (selected == '' && popularController.currentTag != '') {
      if (selectedBangumiIds.isNotEmpty) {
        setState(() {
          selectedBangumiIds.clear();
        });
      }
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag('');
      popularController.clearBangumiList();
      if (popularController.trendList.isEmpty) {
        await popularController.queryBangumiByTrend();
      }
    } else if (selected != '' && selected != popularController.currentTag) {
      if (selectedBangumiIds.isNotEmpty) {
        setState(() {
          selectedBangumiIds.clear();
        });
      }
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag(selected);
      await popularController.queryBangumiByTag(type: 'init');
    }
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
