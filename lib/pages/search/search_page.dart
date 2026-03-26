import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/batch_collect_sheet.dart';
import 'package:kazumi/bean/widget/collect_filter_panel.dart';
import 'package:kazumi/bean/widget/sort_filter_tab_panel.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:kazumi/utils/storage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final CollectController collectController = Modular.get<CollectController>();
  final SearchController searchController = SearchController();
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

  /// Don't use modular singleton here. We may have multiple search pages.
  /// Use a new instance of SearchPageController for each search page.
  final SearchPageController searchPageController = SearchPageController();
  final ScrollController scrollController = ScrollController();

  Set<int> selectedFilterIds = <int>{};

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchPageController.loadSearchHistories();
    selectedFilterIds = getAllFilterIds();
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        searchController.text != '' &&
        searchPageController.bangumiList.length >= 20) {
      KazumiLogger().i('SearchController: search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  Set<int> getAllFilterIds() =>
      <int>{0, ...visibleCollectFolders.map((folder) => folder.id)};

  Widget showSearchOptionPanel() {
    return StatefulBuilder(builder: (context, setSheetState) {
      final sort =
          SearchParser(searchController.text).parseSort()?.toLowerCase() ??
              'heat';
      final selectedSort =
          {'heat', 'rank', 'match'}.contains(sort) ? sort : 'heat';
      final groups = collectController.getCollectGroups();
      final folders = visibleCollectFolders;
      return SortFilterTabPanel(
        sortChild: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<String>(
                value: 'heat',
                label: Text('热度'),
                icon: Icon(Icons.local_fire_department_outlined, size: 18),
              ),
              ButtonSegment<String>(
                value: 'rank',
                label: Text('评分'),
                icon: Icon(Icons.star_outline, size: 18),
              ),
              ButtonSegment<String>(
                value: 'match',
                label: Text('匹配'),
                icon: Icon(Icons.tune, size: 18),
              ),
            ],
            selected: {selectedSort},
            onSelectionChanged: (selected) {
              final nextSort = selected.first;
              searchController.text = searchPageController.attachSortParams(
                searchController.text,
                nextSort,
              );
              searchPageController.searchBangumi(
                searchController.text,
                type: 'init',
              );
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
    });
  }

  List<BangumiItem> getFilteredBangumiList() {
    final selected = selectedFilterIds;
    if (selected.isEmpty) return <BangumiItem>[];
    return searchPageController.bangumiList.where((item) {
      final types = collectController.getCollectTypes(item);
      if (types.isEmpty) {
        return selected.contains(0);
      }
      return types.any(selected.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.inputTag != '') {
        final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        searchController.text = tagString;
        searchPageController.searchBangumi(tagString, type: 'init');
      }
    });
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            context: context,
            builder: (context) {
              return showSearchOptionPanel();
            },
          );
        },
        icon: const Icon(Icons.sort),
        label: const Text("搜索设置"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Observer(builder: (context) {
              final filteredList = getFilteredBangumiList();
              final canBatchSave = searchController.text.trim().isNotEmpty &&
                  filteredList.isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: FocusScope(
                      descendantsAreFocusable: false,
                      child: SearchAnchor.bar(
                        searchController: searchController,
                        barElevation: WidgetStateProperty<double>.fromMap(
                          <WidgetStatesConstraint, double>{WidgetState.any: 0},
                        ),
                        viewElevation: 0,
                        viewLeading: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(Icons.arrow_back),
                        ),
                        isFullScreen: MediaQuery.sizeOf(context).width <
                            LayoutBreakpoint.compact['width']!,
                        suggestionsBuilder: (context, controller) => [
                          Observer(
                            builder: (context) {
                              if (controller.text.isNotEmpty) {
                                return Container(
                                  height: 400,
                                  alignment: Alignment.center,
                                  child: Text("无可用搜索建议，回车以直接检索"),
                                );
                              } else {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var history in searchPageController
                                        .searchHistories
                                        .take(10))
                                      ListTile(
                                        title: Text(history.keyword),
                                        onTap: () {
                                          controller.text = history.keyword;
                                          searchPageController.searchBangumi(
                                              controller.text,
                                              type: 'init');
                                          if (searchController.isOpen) {
                                            searchController
                                                .closeView(history.keyword);
                                          }
                                        },
                                        trailing: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            searchPageController
                                                .deleteSearchHistory(history);
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              }
                            },
                          ),
                        ],
                        onSubmitted: (value) {
                          searchPageController.searchBangumi(value,
                              type: 'init');
                          if (searchController.isOpen) {
                            searchController.closeView(value);
                          }
                        },
                      ),
                    ),
                  ),
                  if (canBatchSave) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '保存当前搜索结果',
                      onPressed: () async {
                        await BatchCollectSheet.show(
                          context: context,
                          items: filteredList,
                          keyword: searchController.text,
                          defaultGroupId: 0,
                        );
                      },
                      icon: const Icon(Icons.saved_search_rounded),
                    ),
                  ],
                ],
              );
            }),
          ),
          Expanded(
            child: Observer(builder: (context) {
              if (searchPageController.isTimeOut) {
                return Center(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: '什么都没有找到 (´;ω;`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            searchPageController.searchBangumi(
                                searchController.text,
                                type: 'init');
                          },
                          text: '点击重试',
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (searchPageController.isLoading &&
                  searchPageController.bangumiList.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }
              int crossCount = 3;
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.compact['width']!) {
                crossCount = 5;
              }
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.medium['width']!) {
                crossCount = 6;
              }
              final filteredList = getFilteredBangumiList();

              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent: MediaQuery.of(context).size.width /
                          crossCount /
                          StyleString.bangumiCoverAspectRatio +
                      MediaQuery.textScalerOf(context).scale(32.0),
                ),
                itemCount: filteredList.isNotEmpty ? filteredList.length : 10,
                itemBuilder: (context, index) {
                  return filteredList.isNotEmpty
                      ? BangumiCardV(
                          enableHero: false,
                          bangumiItem: filteredList[index],
                        )
                      : Container();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
