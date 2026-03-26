import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/batch_collect_sheet.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/bean/widget/collect_manager_sheet.dart';
import 'package:kazumi/bean/widget/custom_dropdown_menu.dart';
import 'package:kazumi/bean/widget/selection_state_overlay.dart';
import 'package:kazumi/bean/widget/two_pane_layout.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/format_utils.dart';
import 'package:kazumi/utils/settings_route.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:provider/provider.dart';

enum CollectViewMode { collect, history, download }

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final CollectController collectController = Modular.get<CollectController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final DownloadController downloadController =
      Modular.get<DownloadController>();
  late NavigationBarState navigationBarState;

  bool syncCollectiblesing = false;
  Box setting = GStorage.setting;

  final GlobalKey selectorKey = GlobalKey();
  final GlobalKey viewModeSelectorKey = GlobalKey();
  final SearchController collectSearchController = SearchController();
  final FocusNode collectSearchFocusNode = FocusNode();
  late final PageController viewModePageController;
  static const int defaultCollectGroupId = 0;
  static const int allCollectFolderId = -1;
  static const int groupSelectionOffset = 1000;
  static const String allCollectFoldersName = '全部';
  int selectedCollectFolderId = allCollectFolderId;
  CollectViewMode selectedViewMode = CollectViewMode.collect;
  String collectSearchKeyword = '';
  final Set<int> selectedCollectBangumiIds = <int>{};
  final Set<String> selectedHistoryKeys = <String>{};
  bool isCollectSelectorExpanded = false;
  bool isViewModeSelectorExpanded = false;
  bool showAlternateSearchHint = false;
  Timer? searchHintTimer;

  bool _isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= TwoPaneDefaults.minWidth;

  bool _isInInfoDetail() => Modular.to.path.startsWith('/tab/collect/info');

  List<CollectFolder> get collectFolders =>
      collectController.getCollectFolders();
  List<CollectGroup> get collectGroups => collectController.getCollectGroups();
  bool get hideBuiltInCollectFolders =>
      setting.get(SettingBoxKey.collectHideBuiltInFolders,
          defaultValue: false) ==
      true;
  List<CollectFolder> get visibleCollectFolders => hideBuiltInCollectFolders
      ? collectFolders.where((folder) => !folder.isBuiltIn).toList()
      : collectFolders;
  bool get foldableOptimization =>
      setting.get(SettingBoxKey.foldableOptimization, defaultValue: false) ==
      true;
  String get collectGridStyle {
    final value = setting.get(SettingBoxKey.collectGridStyle);
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
      setting.get(SettingBoxKey.showRating, defaultValue: true) == true;

  bool get isGroupSelection => selectedCollectFolderId <= -groupSelectionOffset;
  int get selectedGroupId => -selectedCollectFolderId - groupSelectionOffset;

  int selectionForGroup(int groupId) => -(groupId + groupSelectionOffset);

  String get selectedCollectFolderName =>
      selectedCollectFolderId == allCollectFolderId
          ? allCollectFoldersName
          : isGroupSelection
              ? collectController.getCollectGroupName(selectedGroupId)
              : collectController.getCollectFolderName(selectedCollectFolderId);

  List<CollectedBangumi> get selectedCollectibles {
    return collectController.collectibles
        .where((element) =>
            selectedCollectFolderId == allCollectFolderId ||
            (isGroupSelection
                ? collectFolders
                    .where((folder) => folder.groupId == selectedGroupId)
                    .any((folder) => element.containsType(folder.id))
                : element.containsType(selectedCollectFolderId)))
        .toList()
      ..sort((a, b) => b.time.millisecondsSinceEpoch
          .compareTo(a.time.millisecondsSinceEpoch));
  }

  List<History> get filteredHistoriesForDisplay => filterHistoriesByKeyword(
      historyController.histories, collectSearchKeyword);

  List<DownloadRecord> get filteredDownloadRecordsForDisplay =>
      filterDownloadRecordsByKeyword(
          downloadController.records, collectSearchKeyword);

  bool get isHistorySelectionMode =>
      selectedViewMode == CollectViewMode.history &&
      selectedHistoryKeys.isNotEmpty;

  bool get isCollectSelectionMode =>
      selectedViewMode == CollectViewMode.collect &&
      selectedCollectBangumiIds.isNotEmpty;

  List<History> get selectedHistories => historyController.histories
      .where((history) => selectedHistoryKeys.contains(history.key))
      .toList();

  List<CollectedBangumi> get selectedCollectedBangumis => collectController
      .collectibles
      .where((item) => selectedCollectBangumiIds.contains(item.bangumiItem.id))
      .toList();

  List<BangumiItem> get currentSearchResultItems {
    if (collectSearchKeyword.trim().isEmpty) return const <BangumiItem>[];
    switch (selectedViewMode) {
      case CollectViewMode.collect:
        return filterCollectiblesByKeyword(
                selectedCollectibles, collectSearchKeyword)
            .map((e) => e.bangumiItem)
            .toList();
      case CollectViewMode.history:
        return filteredHistoriesForDisplay.map((e) => e.bangumiItem).toList();
      case CollectViewMode.download:
        return filteredDownloadRecordsForDisplay
            .map((e) => BangumiItem(
                  id: e.bangumiId,
                  type: 2,
                  name: e.bangumiName,
                  nameCn: e.bangumiName,
                  summary: '',
                  airDate: '',
                  airWeekday: 0,
                  rank: 0,
                  images: {'large': e.bangumiCover},
                  tags: [],
                  alias: [],
                  ratingScore: 0,
                  votes: 0,
                  votesCount: [],
                  info: '',
                ))
            .toList();
    }
  }

  void onBackPressed(BuildContext context) {
    if (isCollectSelectionMode) {
      setState(() {
        selectedCollectBangumiIds.clear();
      });
      return;
    }
    if (isHistorySelectionMode) {
      setState(() {
        selectedHistoryKeys.clear();
      });
      return;
    }
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (_isInInfoDetail()) {
      Modular.to.navigate('/tab/collect/');
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
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
    final route = '/tab/collect/info/?bangumiId=${item.id}';
    Modular.to.navigate(route, arguments: item);
  }

  @override
  void initState() {
    super.initState();
    collectSearchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    collectController.loadCollectibles();
    historyController.init();
    downloadController.refreshRecords();
    selectedViewMode = getDefaultCollectViewMode();
    viewModePageController = PageController(
      initialPage: _viewModeToPageIndex(selectedViewMode),
    );
    selectedCollectFolderId = getLastSelectedCollectFolderId();
    _ensureSelectedCollectFolderValid();
    persistSelectedCollectFolder();
    searchHintTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() {
        showAlternateSearchHint = !showAlternateSearchHint;
      });
    });
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    Modular.to.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    searchHintTimer?.cancel();
    collectSearchFocusNode.dispose();
    collectSearchController.dispose();
    viewModePageController.dispose();
    navigationBarState.showNavigate();
    Modular.to.removeListener(_handleRouteChange);
    super.dispose();
  }

  CollectViewMode getDefaultCollectViewMode() {
    final String mode =
        setting.get(SettingBoxKey.collectDefaultView, defaultValue: 'collect');
    switch (mode) {
      case 'history':
        return CollectViewMode.history;
      case 'download':
        return CollectViewMode.download;
      case 'collect':
      default:
        return CollectViewMode.collect;
    }
  }

  int getLastSelectedCollectFolderId() {
    final value = setting.get(
      SettingBoxKey.collectLastSelectedFolder,
      defaultValue: allCollectFolderId,
    );
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? allCollectFolderId;
    }
    return allCollectFolderId;
  }

  void persistSelectedCollectFolder() {
    setting.put(
      SettingBoxKey.collectLastSelectedFolder,
      selectedCollectFolderId,
    );
  }

  void _ensureSelectedCollectFolderValid() {
    final previousSelection = selectedCollectFolderId;
    if (selectedCollectFolderId != allCollectFolderId) {
      if (isGroupSelection) {
        final exists =
            collectGroups.any((group) => group.id == selectedGroupId);
        if (!exists) {
          selectedCollectFolderId = allCollectFolderId;
        }
      } else {
        final folders = collectFolders;
        if (folders.isEmpty) {
          selectedCollectFolderId = allCollectFolderId;
        } else {
          final exists =
              folders.any((folder) => folder.id == selectedCollectFolderId);
          if (!exists) {
            selectedCollectFolderId = allCollectFolderId;
          }
        }
      }
    }
    if (selectedCollectFolderId != previousSelection) {
      persistSelectedCollectFolder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTwoPane = _isTwoPane(context);
    final isInDetail = _isInInfoDetail();
    final primaryFab = _buildPrimaryFab();
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
        body: Observer(
          builder: (context) {
            final mainContent = renderBody;
            return TwoPaneLayout(
              isTwoPane: isTwoPane,
              isInDetail: isInDetail,
              foldableOptimization: foldableOptimization,
              onLeftPaneVisibilityChanged: _syncNavigationWithLeftPaneVisibility,
              leftPaneBuilder: (context, _, isTwoPane) => _buildLeftPane(
                mainContent,
                isTwoPane: isTwoPane,
                primaryFab: primaryFab,
              ),
              rightPaneBuilder: (context, _, isTwoPane) =>
                  _buildDetailPane(isTwoPane),
            );
          },
        ),
      ),
    );
  }

  Widget? _buildPrimaryFab() {
    final selectionFavoriteFab = _buildSelectionFavoriteFab();
    if (selectionFavoriteFab != null) return selectionFavoriteFab;
    if (selectedViewMode == CollectViewMode.download) {
      return FloatingActionButton(
        onPressed: () => pushSettingsRoute('/settings/download-settings'),
        child: const Icon(Icons.settings),
      );
    }
    return FloatingActionButton(
      onPressed: selectedViewMode == CollectViewMode.collect
          ? syncCollectibles
          : showHistoryClearDialog,
      child: selectedViewMode == CollectViewMode.collect
          ? (syncCollectiblesing
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(),
                )
              : const Icon(Icons.cloud_sync))
          : const Icon(Icons.clear_all),
    );
  }

  Widget? _buildSelectionFavoriteFab() {
    if (isHistorySelectionMode) {
      return FloatingActionButton(
        tooltip: '删除所选',
        onPressed: showDeleteSelectedHistoriesDialog,
        child: const Icon(Icons.delete),
      );
    }
    return null;
  }

  Widget _buildLeftPane(
    Widget mainContent, {
    required bool isTwoPane,
    required Widget? primaryFab,
  }) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 72,
                child: buildSysAppBar(
                  showDesktopCloseButton:
                      !(_isTwoPane(context) && _isInInfoDetail()),
                ),
              ),
              Expanded(child: mainContent),
            ],
          ),
          if (primaryFab != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: primaryFab,
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

  PreferredSizeWidget buildSysAppBar({bool showDesktopCloseButton = true}) {
    final theme = Theme.of(context);
    return SysAppBar(
      needTopOffset: false,
      toolbarHeight: 72,
      backgroundColor: theme.colorScheme.surface,
      showDesktopCloseButton: showDesktopCloseButton,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  height: 44,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (collectSearchFocusNode.hasFocus ||
                              isCollectSelectorExpanded ||
                              isViewModeSelectorExpanded)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: double.infinity,
                            child: TextButton(
                              key: viewModeSelectorKey,
                              onPressed: showViewModeMenu,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    selectedViewMode == CollectViewMode.collect
                                        ? Icons.favorite
                                        : selectedViewMode ==
                                                CollectViewMode.history
                                            ? Icons.history
                                            : Icons.download,
                                    size: 18,
                                    color: theme.iconTheme.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedViewMode == CollectViewMode.collect
                                        ? '收藏夹'
                                        : selectedViewMode ==
                                                CollectViewMode.history
                                            ? '历史'
                                            : '下载',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (selectedViewMode == CollectViewMode.collect)
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: (collectSearchFocusNode.hasFocus ||
                                      isCollectSelectorExpanded ||
                                      isViewModeSelectorExpanded)
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          if (selectedViewMode == CollectViewMode.collect)
                            SizedBox(
                              height: double.infinity,
                              child: InkWell(
                                key: selectorKey,
                                borderRadius: BorderRadius.circular(10),
                                onTap: showCollectTypeMenu,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedCollectFolderName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 20,
                                        color: theme.iconTheme.color,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: (collectSearchFocusNode.hasFocus ||
                                isCollectSelectorExpanded ||
                                isViewModeSelectorExpanded)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: buildTopCollectSearchField(
                          withBorder: false,
                          densePadding: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: buildAppBarActions(),
    );
  }

  List<Widget> buildAppBarActions() {
    if (isCollectSelectionMode) {
      return <Widget>[
        IconButton(
          tooltip: '修改所选收藏夹',
          icon: const Icon(Icons.favorite),
          onPressed: editSelectedCollectFolders,
        ),
        const SizedBox(width: 4),
      ];
    }
    if (isHistorySelectionMode) {
      return <Widget>[
        IconButton(
          tooltip: '收藏所选',
          icon: const Icon(Icons.favorite),
          onPressed: collectSelectedHistories,
        ),
        const SizedBox(width: 4),
      ];
    }
    if (selectedViewMode != CollectViewMode.collect) return const <Widget>[];
    return <Widget>[
      _buildGridStyleMenuButton(),
      const SizedBox(width: 4),
    ];
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
    await setting.put(SettingBoxKey.collectGridStyle, styles[nextIndex]);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> showViewModeMenu() async {
    final RenderBox renderBox =
        viewModeSelectorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    const collectItem = 'collect';
    const historyItem = 'history';
    const downloadItem = 'download';
    setState(() {
      isViewModeSelectorExpanded = true;
    });
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
            maxWidth: 120,
            items: const [collectItem, historyItem, downloadItem],
            itemBuilder: (item) {
              switch (item) {
                case collectItem:
                  return '收藏夹';
                case historyItem:
                  return '历史';
                case downloadItem:
                  return '下载';
                default:
                  return item;
              }
            },
            itemWidgetBuilder: (item) {
              IconData icon = Icons.help_outline;
              String label = item;
              switch (item) {
                case collectItem:
                  icon = Icons.favorite_border;
                  label = '收藏夹';
                  break;
                case historyItem:
                  icon = Icons.history;
                  label = '历史';
                  break;
                case downloadItem:
                  icon = Icons.download_outlined;
                  label = '下载';
                  break;
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            },
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
    if (mounted) {
      setState(() {
        isViewModeSelectorExpanded = false;
      });
    }
    if (selected == null) return;
    switch (selected) {
      case collectItem:
        switchViewMode(CollectViewMode.collect);
        break;
      case historyItem:
        switchViewMode(CollectViewMode.history);
        break;
      case downloadItem:
        switchViewMode(CollectViewMode.download);
        break;
    }
  }

  int _viewModeToPageIndex(CollectViewMode mode) {
    switch (mode) {
      case CollectViewMode.collect:
        return 0;
      case CollectViewMode.history:
        return 1;
      case CollectViewMode.download:
        return 2;
    }
  }

  CollectViewMode _pageIndexToViewMode(int index) {
    switch (index) {
      case 0:
        return CollectViewMode.collect;
      case 1:
        return CollectViewMode.history;
      case 2:
      default:
        return CollectViewMode.download;
    }
  }

  void switchViewMode(CollectViewMode mode) {
    switchViewModeWithSync(mode, syncPage: true);
  }

  void switchViewModeWithSync(CollectViewMode mode, {required bool syncPage}) {
    if (mode == selectedViewMode) return;
    if (mode == CollectViewMode.history) {
      historyController.init();
    }
    if (mode == CollectViewMode.download) {
      downloadController.refreshRecords();
    }
    setState(() {
      if (selectedViewMode == CollectViewMode.collect) {
        selectedCollectBangumiIds.clear();
      }
      if (selectedViewMode == CollectViewMode.history) {
        selectedHistoryKeys.clear();
      }
      selectedViewMode = mode;
    });
    if (!syncPage || !viewModePageController.hasClients) return;
    final int targetPage = _viewModeToPageIndex(mode);
    final int? currentPage = viewModePageController.page?.round();
    if (currentPage == targetPage) return;
    viewModePageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget get renderBody {
    return PageView(
      controller: viewModePageController,
      onPageChanged: (index) {
        switchViewModeWithSync(_pageIndexToViewMode(index), syncPage: false);
      },
      children: [
        renderCollectBody,
        renderHistoryBody,
        renderDownloadBody,
      ],
    );
  }

  Widget get renderCollectBody {
    _ensureSelectedCollectFolderValid();
    if (collectController.collectibles.isEmpty) {
      if (selectedCollectBangumiIds.isNotEmpty) {
        selectedCollectBangumiIds.clear();
      }
      return const Center(
        child: Text('啊嘞, 还没有收藏夹内容 (´;ω;`)'),
      );
    }
    if (selectedCollectibles.isEmpty) {
      return Center(
        child: Text('啊嘞, $selectedCollectFolderName里还没有内容 (´;ω;`)'),
      );
    }
    final filteredCollectibles =
        filterCollectiblesByKeyword(selectedCollectibles, collectSearchKeyword);
    return Column(
      children: [
        Expanded(
          child: filteredCollectibles.isEmpty
              ? const Center(
                  child: Text('没有匹配的收藏夹结果'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return contentCollectGrid(
                      filteredCollectibles,
                      constraints.maxWidth,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildTopCollectSearchField({
    bool withBorder = true,
    bool densePadding = false,
  }) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: TextField(
        expands: true,
        minLines: null,
        maxLines: null,
        controller: collectSearchController,
        focusNode: collectSearchFocusNode,
        textAlignVertical: TextAlignVertical.center,
        onChanged: (value) {
          setState(() {
            collectSearchKeyword = value.trim();
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: showAlternateSearchHint ? '左侧文本按钮可切换页面' : '搜索',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: densePadding ? 8 : 12,
            vertical: 0,
          ),
          prefixIcon: IconButton(
            tooltip: '保存当前搜索结果',
            icon: const Icon(Icons.saved_search_rounded, size: 18),
            onPressed: (collectSearchKeyword.trim().isNotEmpty &&
                    currentSearchResultItems.isNotEmpty)
                ? showSaveSearchResultSheet
                : null,
          ),
          suffixIcon: collectSearchKeyword.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    collectSearchController.clear();
                    setState(() {
                      collectSearchKeyword = '';
                    });
                  },
                ),
          border: withBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                )
              : InputBorder.none,
          enabledBorder: withBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                )
              : InputBorder.none,
        ),
      ),
    );
  }

  List<CollectedBangumi> filterCollectiblesByKeyword(
      List<CollectedBangumi> source, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((collected) {
      final item = collected.bangumiItem;
      final aliases = item.alias.join(' ');
      final searchable = <String>[
        item.id.toString(),
        item.name,
        item.nameCn,
        item.summary,
        aliases,
      ].join('\n').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  Widget get renderHistoryBody {
    if (historyController.histories.isEmpty) {
      if (selectedHistoryKeys.isNotEmpty) {
        selectedHistoryKeys.clear();
      }
      return const Center(
        child: Text('没有找到历史记录 (´;ω;`)'),
      );
    }
    if (filteredHistoriesForDisplay.isEmpty) {
      return const Center(
        child: Text('没有匹配的历史结果'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return contentHistoryGrid(
          filteredHistoriesForDisplay,
          constraints.maxWidth,
        );
      },
    );
  }

  Widget get renderDownloadBody {
    if (downloadController.records.isEmpty) {
      return const Center(
        child: Text('暂无离线下载'),
      );
    }
    if (filteredDownloadRecordsForDisplay.isEmpty) {
      return const Center(
        child: Text('没有匹配的下载结果'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        StyleString.cardSpace * 2,
        StyleString.cardSpace,
        StyleString.cardSpace * 2,
        StyleString.cardSpace,
      ),
      itemCount: filteredDownloadRecordsForDisplay.length,
      itemBuilder: (context, index) {
        final record = filteredDownloadRecordsForDisplay[index];
        return buildRecordCard(record);
      },
    );
  }

  Future<void> showSaveSearchResultSheet() async {
    await BatchCollectSheet.show(
      context: context,
      items: currentSearchResultItems,
      keyword: collectSearchKeyword,
      defaultGroupId: resolveSearchTargetGroupId(),
      onApplied: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  int resolveSearchTargetGroupId() {
    int targetGroupId = defaultCollectGroupId;
    if (selectedViewMode == CollectViewMode.collect) {
      if (isGroupSelection) {
        targetGroupId = selectedGroupId;
      } else {
        for (final folder in collectFolders) {
          if (folder.id == selectedCollectFolderId) {
            targetGroupId = folder.groupId;
            break;
          }
        }
      }
    }
    return targetGroupId;
  }

  List<History> filterHistoriesByKeyword(List<History> source, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((history) {
      final item = history.bangumiItem;
      final searchable = <String>[
        item.id.toString(),
        item.name,
        item.nameCn,
        history.adapterName,
        history.lastSrc,
        history.lastWatchEpisodeName,
        history.lastWatchEpisode.toString(),
      ].join('\n').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<DownloadRecord> filterDownloadRecordsByKeyword(
      List<DownloadRecord> source, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((record) {
      final episodeNames = record.episodes.values
          .map((episode) => episode.episodeName)
          .join(' ');
      final searchable = <String>[
        record.bangumiId.toString(),
        record.bangumiName,
        record.pluginName,
        episodeNames,
      ].join('\n').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  Future<void> showCollectTypeMenu() async {
    final folders = visibleCollectFolders;
    final groups = collectGroups;
    if (groups.isEmpty && folders.isEmpty) return;
    const String manageFoldersItem = '管理收藏夹';
    const String allFoldersItem = allCollectFoldersName;
    const String groupPrefix = 'group:';
    const String folderPrefix = 'folder:';
    final menuItems = <String>[manageFoldersItem, allFoldersItem];
    final dividerAfter = <int>{0, 1};

    for (final group in groups) {
      final groupKey = '$groupPrefix${group.id}';
      menuItems.add(groupKey);
      final groupedFolders =
          folders.where((folder) => folder.groupId == group.id).toList();
      for (final folder in groupedFolders) {
        menuItems.add('$folderPrefix${folder.id}');
      }
      dividerAfter.add(menuItems.length - 1);
    }

    final RenderBox renderBox =
        selectorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    setState(() {
      isCollectSelectorExpanded = true;
    });
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
            maxWidth: 140,
            items: menuItems,
            itemBuilder: (item) {
              if (item == manageFoldersItem || item == allFoldersItem) {
                return item;
              }
              if (item.startsWith(groupPrefix)) {
                final groupId =
                    int.tryParse(item.substring(groupPrefix.length));
                if (groupId == null) return item;
                return collectController.getCollectGroupName(groupId);
              }
              if (item.startsWith(folderPrefix)) {
                final folderId =
                    int.tryParse(item.substring(folderPrefix.length));
                if (folderId == null) return item;
                return '  ${collectController.getCollectFolderName(folderId)}';
              }
              return item;
            },
            dividerAfterIndices: dividerAfter,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
    if (mounted) {
      setState(() {
        isCollectSelectorExpanded = false;
      });
    }

    if (selected == null) return;
    if (selected == manageFoldersItem) {
      await showCollectFolderManager();
      if (!mounted) return;
      setState(() {
        _ensureSelectedCollectFolderValid();
        persistSelectedCollectFolder();
      });
      return;
    }
    if (selected == allFoldersItem) {
      if (selectedCollectFolderId == allCollectFolderId) return;
      setState(() {
        selectedCollectFolderId = allCollectFolderId;
        persistSelectedCollectFolder();
      });
      return;
    }
    if (selected.startsWith(groupPrefix)) {
      final groupId = int.tryParse(selected.substring(groupPrefix.length));
      if (groupId == null) return;
      final groupSelection = selectionForGroup(groupId);
      if (groupSelection == selectedCollectFolderId) return;
      setState(() {
        selectedCollectFolderId = groupSelection;
        persistSelectedCollectFolder();
      });
      return;
    }
    if (selected.startsWith(folderPrefix)) {
      final folderId = int.tryParse(selected.substring(folderPrefix.length));
      if (folderId == null || folderId == selectedCollectFolderId) return;
      setState(() {
        selectedCollectFolderId = folderId;
        persistSelectedCollectFolder();
      });
      return;
    }
    CollectFolder? selectedFolder;
    for (final folder in folders) {
      if (folder.name == selected) {
        selectedFolder = folder;
        break;
      }
    }
    if (selectedFolder == null ||
        selectedFolder.id == selectedCollectFolderId) {
      return;
    }
    final folderToSelect = selectedFolder;
    setState(() {
      selectedCollectFolderId = folderToSelect.id;
      persistSelectedCollectFolder();
    });
  }

  Future<void> showCollectFolderManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return CollectManagerSheet(
          collectController: collectController,
          hideBuiltInCollectFolders: hideBuiltInCollectFolders,
          defaultCollectGroupId: defaultCollectGroupId,
        );
      },
    );
  }

  Widget contentCollectGrid(
      List<CollectedBangumi> items, double availableWidth) {
    final int crossCount = Utils.getGridCrossCount(
      availableWidth: availableWidth,
      useDetailedGrid: useDetailedGrid,
      useListGrid: useListGrid,
    );
    final double gridPaddingHorizontal = StyleString.cardSpace * 4;
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
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            StyleString.cardSpace * 2,
            StyleString.cardSpace,
            StyleString.cardSpace * 2,
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: StyleString.cardSpace - 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: mainAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final item = items[index];
                final itemId = item.bangumiItem.id;
                final isSelected = selectedCollectBangumiIds.contains(itemId);
                return Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () {
                        toggleCollectSelection(itemId, forceSelect: true);
                      },
                      onTap: isCollectSelectionMode
                          ? () {
                              toggleCollectSelection(itemId);
                            }
                          : null,
                      child: Stack(
                        children: [
                          IgnorePointer(
                            ignoring: isCollectSelectionMode,
                            child: useDetailedGrid
                                ? BangumiTimelineCard(
                                    bangumiItem: item.bangumiItem,
                                    cardHeight: mainAxisExtent,
                                    showRating: showRating,
                                    onTap: () {
                                      _openInfo(item.bangumiItem);
                                    },
                                  )
                                : useListGrid
                                    ? BangumiCardList(
                                        bangumiItem: item.bangumiItem,
                                        canTap: true,
                                        itemHeight: mainAxisExtent,
                                        showRating: showRating,
                                        onTap: () {
                                          _openInfo(item.bangumiItem);
                                        },
                                      )
                                    : useCompactGrid
                                        ? BangumiCardCompact(
                                            bangumiItem: item.bangumiItem,
                                            canTap: true,
                                            onTap: () {
                                              _openInfo(item.bangumiItem);
                                            },
                                          )
                                        : BangumiCardV(
                                            bangumiItem: item.bangumiItem,
                                            canTap: true,
                                            onTap: () {
                                              _openInfo(item.bangumiItem);
                                            },
                                          ),
                          ),
                          SelectionStateOverlay(
                            isSelectionMode: isCollectSelectionMode,
                            isSelected: isSelected,
                            borderRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget contentHistoryGrid(List<History> items, double availableWidth) {
    final int crossCount = Utils.getGridCrossCount(
      availableWidth: availableWidth,
      useDetailedGrid: true,
      useListGrid: false,
    );
    const double cardHeight = 120;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            StyleString.cardSpace * 2 - 6,
            StyleString.cardSpace - 6,
            StyleString.cardSpace * 2 - 6,
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: StyleString.cardSpace - 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              mainAxisExtent: cardHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final historyItem = items[index];
                final isSelected =
                    selectedHistoryKeys.contains(historyItem.key);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    toggleHistorySelection(historyItem, forceSelect: true);
                  },
                  onTap: isHistorySelectionMode
                      ? () {
                          toggleHistorySelection(historyItem);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Stack(
                      children: [
                        IgnorePointer(
                          ignoring: isHistorySelectionMode,
                          child: BangumiHistoryCardV(
                            cardHeight: cardHeight,
                            historyItem: historyItem,
                            onOpenInfo: () {
                              _openInfo(historyItem.bangumiItem);
                            },
                          ),
                        ),
                        SelectionStateOverlay(
                          isSelectionMode: isHistorySelectionMode,
                          isSelected: isSelected,
                          borderRadius: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildRecordCard(DownloadRecord record) {
    final episodes = record.episodes.values.toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    final completedCount = downloadController.completedCount(record);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                record.bangumiCover,
                width: 48,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 64,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_outlined),
                ),
              ),
            ),
            title: Text(
              record.bangumiName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '来源: ${record.pluginName} · $completedCount/${episodes.length} 已完成',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  confirmDeleteRecord(record);
                } else if (value == 'resume_all') {
                  downloadController.resumeAllDownloads(
                    record.bangumiId,
                    record.pluginName,
                  );
                  KazumiDialog.showToast(message: '已开始恢复下载');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'resume_all',
                  child: Text('开始全部'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除全部'),
                ),
              ],
            ),
          ),
          ...episodes.map((ep) => buildEpisodeTile(record, ep)),
        ],
      ),
    );
  }

  Widget buildEpisodeTile(DownloadRecord record, DownloadEpisode episode) {
    final statusIcon = getStatusIcon(episode);
    final statusText = getStatusText(record, episode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.episodeName.isNotEmpty
                      ? episode.episodeName
                      : '第${episode.episodeNumber}集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: episode.status == DownloadStatus.failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (episode.status == DownloadStatus.downloading) ...[
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: episode.progressPercent,
                minHeight: 3,
              ),
            ),
            const SizedBox(width: 8),
          ],
          ...getActionButtons(record, episode),
        ],
      ),
    );
  }

  Widget getStatusIcon(DownloadEpisode episode) {
    switch (episode.status) {
      case DownloadStatus.completed:
        return Icon(Icons.offline_pin,
            size: 20, color: Theme.of(context).colorScheme.primary);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: episode.progressPercent,
            strokeWidth: 2,
          ),
        );
      case DownloadStatus.failed:
        return Icon(Icons.error_outline,
            size: 20, color: Theme.of(context).colorScheme.error);
      case DownloadStatus.paused:
        return Icon(Icons.pause_circle_outline,
            size: 20, color: Theme.of(context).colorScheme.outline);
      case DownloadStatus.pending:
        return Icon(Icons.hourglass_empty,
            size: 20, color: Theme.of(context).colorScheme.outline);
      case DownloadStatus.resolving:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return const SizedBox(width: 20, height: 20);
    }
  }

  String getStatusText(DownloadRecord record, DownloadEpisode episode) {
    switch (episode.status) {
      case DownloadStatus.completed:
        return '已完成  ${formatBytes(episode.totalBytes)}';
      case DownloadStatus.downloading:
        final speed = downloadController.getSpeed(
          record.bangumiId,
          record.pluginName,
          episode.episodeNumber,
        );
        final speedText = speed > 0 ? ' · ${formatSpeed(speed)}' : '';
        return '${(episode.progressPercent * 100).toStringAsFixed(0)}%  '
            '${episode.downloadedSegments}/${episode.totalSegments}$speedText';
      case DownloadStatus.failed:
        return episode.errorMessage.isNotEmpty ? episode.errorMessage : '下载失败';
      case DownloadStatus.paused:
        return '已暂停  ${(episode.progressPercent * 100).toStringAsFixed(0)}%';
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.resolving:
        return '解析视频源中';
      default:
        return '';
    }
  }

  List<Widget> getActionButtons(
      DownloadRecord record, DownloadEpisode episode) {
    final buttons = <Widget>[];
    switch (episode.status) {
      case DownloadStatus.completed:
        buttons.add(IconButton(
          icon: Icon(Icons.play_circle_outline,
              size: 20, color: Theme.of(context).colorScheme.primary),
          onPressed: () => playEpisode(record, episode),
          tooltip: '播放',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.downloading:
        buttons.add(IconButton(
          icon: const Icon(Icons.pause, size: 20),
          onPressed: () => downloadController.pauseDownload(
            record.bangumiId,
            record.pluginName,
            episode.episodeNumber,
          ),
          tooltip: '暂停',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.paused:
        buttons.add(IconButton(
          icon: const Icon(Icons.play_arrow, size: 20),
          onPressed: () => downloadController.retryDownload(
            bangumiId: record.bangumiId,
            pluginName: record.pluginName,
            episodeNumber: episode.episodeNumber,
          ),
          tooltip: '继续',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.failed:
        buttons.add(IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => downloadController.retryDownload(
            bangumiId: record.bangumiId,
            pluginName: record.pluginName,
            episodeNumber: episode.episodeNumber,
          ),
          tooltip: '重试',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.pending:
        buttons.add(IconButton(
          icon: Icon(Icons.priority_high,
              size: 20, color: Theme.of(context).colorScheme.primary),
          onPressed: () {
            downloadController.priorityDownload(
              bangumiId: record.bangumiId,
              pluginName: record.pluginName,
              episodeNumber: episode.episodeNumber,
            );
            KazumiDialog.showToast(message: '已插队优先下载');
          },
          tooltip: '优先下载',
          visualDensity: VisualDensity.compact,
        ));
        break;
      default:
        break;
    }

    buttons.add(IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      onPressed: () => confirmDeleteEpisode(record, episode),
      tooltip: '删除',
      visualDensity: VisualDensity.compact,
    ));
    return buttons;
  }

  void playEpisode(DownloadRecord record, DownloadEpisode episode) {
    final localPath = downloadController.getLocalVideoPath(
      record.bangumiId,
      record.pluginName,
      episode.episodeNumber,
    );
    if (localPath == null) {
      KazumiDialog.showToast(message: '本地文件不存在');
      return;
    }

    final bangumiItem = BangumiItem(
      id: record.bangumiId,
      type: 2,
      name: record.bangumiName,
      nameCn: record.bangumiName,
      summary: '',
      airDate: '',
      airWeekday: 0,
      rank: 0,
      images: {'large': record.bangumiCover},
      tags: [],
      alias: [],
      ratingScore: 0.0,
      votes: 0,
      votesCount: [],
      info: '',
    );

    final downloadedEpisodes = downloadController.getCompletedEpisodes(
      record.bangumiId,
      record.pluginName,
    );

    final videoPageController = Modular.get<VideoPageController>();
    videoPageController.initForOfflinePlayback(
      bangumiItem: bangumiItem,
      pluginName: record.pluginName,
      episodeNumber: episode.episodeNumber,
      episodeName: episode.episodeName,
      road: episode.road,
      videoPath: localPath,
      downloadedEpisodes: downloadedEpisodes,
    );

    Modular.to.pushNamed('/video/');
  }

  void confirmDeleteEpisode(DownloadRecord record, DownloadEpisode episode) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        title: const Text('删除下载'),
        content: Text(
            '确定要删除「${episode.episodeName.isNotEmpty ? episode.episodeName : '第${episode.episodeNumber}集'}」的下载文件吗？'),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              downloadController.deleteEpisode(
                record.bangumiId,
                record.pluginName,
                episode.episodeNumber,
              );
              KazumiDialog.dismiss();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void confirmDeleteRecord(DownloadRecord record) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        title: const Text('删除全部下载'),
        content: Text('确定要删除「${record.bangumiName}」的所有下载文件吗？'),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              downloadController.deleteRecord(
                record.bangumiId,
                record.pluginName,
              );
              KazumiDialog.dismiss();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> syncCollectibles() async {
    bool webDavenable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (!webDavenable) {
      KazumiDialog.showToast(message: 'webDav未启用, 同步功能不可用');
      return;
    }
    if (syncCollectiblesing) {
      return;
    }
    setState(() {
      syncCollectiblesing = true;
    });
    await collectController.syncCollectibles();
    setState(() {
      syncCollectiblesing = false;
    });
  }

  void showHistoryClearDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('记录管理'),
          content: const Text('确认要清除所有历史记录吗?'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                historyController.clearAll();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void toggleHistorySelection(History history, {bool forceSelect = false}) {
    setState(() {
      final key = history.key;
      if (forceSelect) {
        selectedHistoryKeys.add(key);
        return;
      }
      if (selectedHistoryKeys.contains(key)) {
        selectedHistoryKeys.remove(key);
      } else {
        selectedHistoryKeys.add(key);
      }
    });
  }

  void toggleCollectSelection(int bangumiId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        selectedCollectBangumiIds.add(bangumiId);
        return;
      }
      if (selectedCollectBangumiIds.contains(bangumiId)) {
        selectedCollectBangumiIds.remove(bangumiId);
      } else {
        selectedCollectBangumiIds.add(bangumiId);
      }
    });
  }

  Future<void> editSelectedCollectFolders() async {
    final selected = selectedCollectedBangumis;
    if (selected.isEmpty) {
      setState(() {
        selectedCollectBangumiIds.clear();
      });
      return;
    }
    await showCollectFolderSelectionForItems(
      selected.map((e) => e.bangumiItem).toList(),
    );
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

  Future<void> collectSelectedHistories() async {
    final selected = selectedHistories;
    if (selected.isEmpty) {
      setState(() {
        selectedHistoryKeys.clear();
      });
      return;
    }
    final unique = <int, BangumiItem>{};
    for (final history in selected) {
      unique[history.bangumiItem.id] = history.bangumiItem;
    }
    await showCollectFolderSelectionForItems(unique.values.toList());
  }

  void showDeleteSelectedHistoriesDialog() {
    final selected = selectedHistories;
    if (selected.isEmpty) {
      setState(() {
        selectedHistoryKeys.clear();
      });
      return;
    }
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('删除历史'),
          content: Text('确认删除选中的 ${selected.length} 条历史记录吗？'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                KazumiDialog.dismiss();
                await deleteSelectedHistories(selected);
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteSelectedHistories(List<History> selected) async {
    if (selected.isEmpty) return;
    KazumiDialog.showLoading(msg: '删除中');
    try {
      await historyController.deleteHistories(selected);
    } finally {
      KazumiDialog.dismiss();
    }
    if (!mounted) return;
    setState(() {
      selectedHistoryKeys.clear();
    });
    KazumiDialog.showToast(message: '已删除 ${selected.length} 条历史记录');
  }
}
