import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class NavigationBarState extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isHide = false;
  bool _isBottom = false;

  int get selectedIndex => _selectedIndex;

  bool get isHide => _isHide;

  bool get isBottom => _isBottom;

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    if (_isHide) return;
    _isHide = true;
    notifyListeners();
  }

  void showNavigate() {
    if (!_isHide) return;
    _isHide = false;
    notifyListeners();
  }
}

// 通用导航项
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final PageController _page = PageController();
  final GlobalKey _pageViewKey = GlobalKey();
  final NavigationBarState _navigationBarState = NavigationBarState();
  final setting = GStorage.setting;
  StreamSubscription<BoxEvent>? _collectDefaultViewSubscription;
  StreamSubscription<BoxEvent>? _foldableOptimizationSubscription;
  static const int _collectNavIndex = 2;

  // 通用导航内容
  static const List<_NavItem> _baseNavItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home, '推荐'),
    _NavItem(Icons.timeline_outlined, Icons.timeline, '时间表'),
    _NavItem(Icons.favorite_outlined, Icons.favorite, '收藏夹'),
    _NavItem(Icons.settings_outlined, Icons.settings, '设置'),
  ];

  _NavItem _collectNavItemByDefaultView() {
    final dynamic rawMode =
        setting.get(SettingBoxKey.collectDefaultView, defaultValue: 'collect');
    final String mode = rawMode is String ? rawMode : 'collect';
    switch (mode) {
      case 'history':
        return const _NavItem(Icons.history, Icons.history, '历史');
      case 'download':
        return const _NavItem(Icons.download_outlined, Icons.download, '下载');
      case 'collect':
      default:
        return const _NavItem(Icons.favorite_outlined, Icons.favorite, '收藏夹');
    }
  }

  List<_NavItem> get _navItems {
    final items = _baseNavItems.toList();
    items[_collectNavIndex] = _collectNavItemByDefaultView();
    return items;
  }

  List<NavigationDestination> get _bottomDestinations => _navItems
      .map((e) => NavigationDestination(
          selectedIcon: Icon(e.selectedIcon),
          icon: Icon(e.icon),
          label: e.label))
      .toList();

  List<NavigationRailDestination> get _sideDestinations => _navItems
      .map((e) => NavigationRailDestination(
          selectedIcon: Icon(e.selectedIcon),
          icon: Icon(e.icon),
          label: Text(e.label)))
      .toList();

  Widget _buildPageView() {
    return PageView.builder(
      key: _pageViewKey,
      physics: const NeverScrollableScrollPhysics(),
      controller: _page,
      itemCount: menu.size,
      itemBuilder: (_, __) => const RouterOutlet(),
    );
  }

  @override
  void initState() {
    super.initState();
    Modular.to.addListener(_syncSelectedIndexWithRoute);
    _collectDefaultViewSubscription =
        setting.watch(key: SettingBoxKey.collectDefaultView).listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _foldableOptimizationSubscription =
        setting.watch(key: SettingBoxKey.foldableOptimization).listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectedIndexWithRoute();
    });
  }

  @override
  void dispose() {
    Modular.to.removeListener(_syncSelectedIndexWithRoute);
    _collectDefaultViewSubscription?.cancel();
    _foldableOptimizationSubscription?.cancel();
    _page.dispose();
    _navigationBarState.dispose();
    super.dispose();
  }

  int _resolveSelectedIndex(String path) {
    for (int i = 0; i < menu.size; i++) {
      final menuPath = "/tab${menu.getPath(i)}";
      if (path == menuPath || path.startsWith("$menuPath/")) {
        return i;
      }
    }
    return 0;
  }

  void _syncSelectedIndexWithRoute() {
    if (!mounted) {
      return;
    }
    final currentPath = Modular.to.path;
    final resolvedIndex = _resolveSelectedIndex(currentPath);
    if (resolvedIndex != _navigationBarState.selectedIndex) {
      _navigationBarState.updateSelectedIndex(resolvedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NavigationBarState>.value(
        value: _navigationBarState,
        child: Consumer<NavigationBarState>(builder: (context, state, _) {
          return LayoutBuilder(builder: (context, constraints) {
            final forceBottom = setting.get(
                  SettingBoxKey.foldableOptimization,
                  defaultValue: false,
                ) ==
                true;
            final bool useSideByLegacyRule =
                MediaQuery.of(context).orientation == Orientation.landscape;
            final bool useSideByWidthRule =
                constraints.maxWidth >= LayoutBreakpoint.medium['width']!;
            final bool useSide = useSideByLegacyRule || useSideByWidthRule;
            state._isBottom = forceBottom || !useSide;
            final bool showBottomNavigation = state._isBottom && !state.isHide;
            return state._isBottom
                ? bottomMenuWidget(
                    context,
                    state,
                    showBottomNavigation: showBottomNavigation,
                  )
                : sideMenuWidget(context, state);
          });
        }));
  }

  Widget bottomMenuWidget(
    BuildContext context,
    NavigationBarState state, {
    required bool showBottomNavigation,
  }) {
    return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: _buildPageView(),
        ),
        bottomNavigationBar: showBottomNavigation
            ? NavigationBar(
                destinations: _bottomDestinations,
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              )
            : const SizedBox(height: 0));
  }

  Widget sideMenuWidget(
    BuildContext context,
    NavigationBarState state,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: Visibility(
              visible: !state.isHide,
              child: DragToMoveArea(
                child: NavigationRail(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainer,
                  groupAlignment: 1.0,
                  leading: FloatingActionButton(
                    elevation: 0,
                    heroTag: null,
                    onPressed: () {
                      Modular.to.pushNamed('/tab/search/');
                    },
                    child: const Icon(Icons.search),
                  ),
                  labelType: NavigationRailLabelType.selected,
                  destinations: _sideDestinations,
                  selectedIndex: state.selectedIndex,
                  onDestinationSelected: (int index) {
                    state.updateSelectedIndex(index);
                    Modular.to.navigate("/tab${menu.getPath(index)}/");
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
                child: _buildPageView(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
