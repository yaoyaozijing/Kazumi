import 'dart:async';
import 'dart:math';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/mortis.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/two_pane_layout.dart';
import 'package:url_launcher/url_launcher.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const Duration _kLogoCarouselInterval = Duration(seconds: 5);
  static const Duration _kLogoTapComboTimeout = Duration(milliseconds: 480);
  static const int _kLogoTapTriggerCount = 5;
  static const int _kLogoLinkCount = 6;
  late NavigationBarState navigationBarState;
  final MyController myController = Modular.get<MyController>();
  bool _logoCarouselMode = false;
  int _logoLinkIndex = 0;
  int _logoTapCount = 0;
  Timer? _logoCarouselTimer;
  Timer? _logoTapResetTimer;
  StreamSubscription<BoxEvent>? _foldableOptimizationSubscription;
  bool get foldableOptimization =>
      GStorage.setting.get(
        SettingBoxKey.foldableOptimization,
        defaultValue: false,
      ) ==
      true;

  bool _isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= TwoPaneDefaults.minWidth;

  bool _isInSettingsDetail() => Modular.to.path.startsWith('/tab/my/settings');

  Future<void> _launchExternal(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildLinkIcon({
    IconData? icon,
    Widget? iconWidget,
    required String tip,
    String? url,
    VoidCallback? onTap,
    bool expanded = true,
  }) {
    assert(icon != null || iconWidget != null);
    assert(onTap != null || url != null);
    final child = Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? () => _launchExternal(url!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget ?? Icon(icon!, size: 22),
            ],
          ),
        ),
      ),
    );
    if (!expanded) {
      return child;
    }
    return Expanded(child: child);
  }

  List<_MyLinkItem> _buildLinkItems(Color themedIconColor) {
    return [
      _MyLinkItem(
        tip: '项目主页：Kazumi.app',
        iconWidget: Icon(
          Icons.public_rounded,
          size: 22,
          color: themedIconColor,
        ),
        onTap: () => _launchExternal(Api.projectUrl),
      ),
      _MyLinkItem(
        tip: '代码仓库：Github',
        iconWidget: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SvgPicture.asset(
            'assets/images/github.svg',
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              themedIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        onTap: () => _launchExternal(Api.sourceUrl),
      ),
      _MyLinkItem(
        tip: '开源许可证',
        iconWidget: Icon(
          Icons.gavel_rounded,
          size: 22,
          color: themedIconColor,
        ),
        onTap: () => _openSettings('/tab/my/settings/license'),
      ),
      _MyLinkItem(
        tip: '图标创作：Yuquanaaa 的 Pixiv',
        iconWidget: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SvgPicture.asset(
            'assets/images/pixiv.svg',
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              themedIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        onTap: () => _launchExternal(Api.iconUrl),
      ),
      _MyLinkItem(
        tip: '番剧索引: Bangumi',
        iconWidget: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SvgPicture.asset(
            'assets/images/bangumi.svg',
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              themedIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        onTap: () => _launchExternal(Api.bangumiIndex),
      ),
      _MyLinkItem(
        tip: '弹幕来源：DandanPlay',
        iconWidget: Icon(
          Icons.subtitles_rounded,
          size: 22,
          color: themedIconColor,
        ),
        onTap: _showDanmakuSourceDialog,
      ),
    ];
  }

  void _startLogoCarousel(int count) {
    _logoCarouselTimer?.cancel();
    _logoCarouselTimer = Timer.periodic(_kLogoCarouselInterval, (_) {
      if (!mounted) return;
      setState(() {
        _logoLinkIndex = (_logoLinkIndex + 1) % count;
      });
    });
  }

  void _stopLogoCarousel() {
    _logoCarouselTimer?.cancel();
    _logoCarouselTimer = null;
  }

  void _onLogoTap(int count) {
    _logoTapResetTimer?.cancel();
    _logoTapCount += 1;
    if (_logoTapCount > 2 && _logoTapCount < _kLogoTapTriggerCount) {
      final remaining = _kLogoTapTriggerCount - _logoTapCount;
      final action = _logoCarouselMode ? '关闭轮换' : '开启轮换';
      KazumiDialog.showToast(message: '剩余$remaining次$action');
    }
    if (_logoTapCount < _kLogoTapTriggerCount) {
      _logoTapResetTimer = Timer(_kLogoTapComboTimeout, () {
        _logoTapCount = 0;
      });
      return;
    }
    _logoTapCount = 0;
    setState(() {
      _logoCarouselMode = !_logoCarouselMode;
      if (_logoCarouselMode) {
        _logoLinkIndex = 0;
        _startLogoCarousel(count);
      } else {
        _stopLogoCarousel();
      }
    });
  }

  void _showDanmakuSourceDialog() {
    final danmakuId = 'ID: ${mortis['id']}';
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('弹幕来源'),
          content: Text('DandanPlay\n$danmakuId'),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: danmakuId));
                KazumiDialog.dismiss();
                KazumiDialog.showToast(message: '已复制 $danmakuId');
              },
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                _launchExternal(Api.dandanIndex);
              },
              child: const Text('前往DandanPlay'),
            ),
          ],
        );
      },
    );
  }

  void _openSettings(String route) {
    if (_isTwoPane(context)) {
      Modular.to.navigate(route);
      return;
    }
    Modular.to.pushNamed(route);
  }

  void _handleRouteChange() {
    if (!mounted) {
      return;
    }
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

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (_isInSettingsDetail()) {
      Modular.to.navigate('/tab/my/');
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
    _foldableOptimizationSubscription = GStorage.setting
        .watch(key: SettingBoxKey.foldableOptimization)
        .listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _logoCarouselMode = Random().nextBool();
    if (_logoCarouselMode) {
      _startLogoCarousel(_kLogoLinkCount);
    }
    Modular.to.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    _stopLogoCarousel();
    _logoTapResetTimer?.cancel();
    _foldableOptimizationSubscription?.cancel();
    navigationBarState.showNavigate();
    Modular.to.removeListener(_handleRouteChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final isTwoPane = _isTwoPane(context);
    final isInDetail = _isInSettingsDetail();
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
          leftPaneBuilder: (context, _, __) => _buildLeftPane(
            context,
            fontFamily,
          ),
          rightPaneBuilder: (context, _, __) => _buildDetailPane(context),
        ),
      ),
    );
  }

  Widget _buildLeftPane(
    BuildContext context,
    String? fontFamily,
  ) {
    return SafeArea(
      bottom: false,
      child: _buildSettingsList(context, fontFamily),
    );
  }

  Widget _buildDetailPane(BuildContext context) {
    return RouterOutlet();
  }

  Widget _buildSettingsList(BuildContext context, String? fontFamily) {
    final themedIconColor = Theme.of(context).colorScheme.primary;
    final linkItems = _buildLinkItems(themedIconColor);
    final currentLink = linkItems[_logoLinkIndex % linkItems.length];
    final currentCarouselKey = ValueKey<int>(_logoLinkIndex % linkItems.length);
    return SettingsList(
      maxWidth: 1000,
      sections: [
        SettingsSection(
          tiles: [
            SettingsTile(
              onPressed: (_) => _onLogoTap(linkItems.length),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/mypage_logo.png',
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: child,
                        ),
                      );
                    },
                    child: _logoCarouselMode
                        ? Center(
                            key: const ValueKey('carousel_mode'),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 1500),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                final isIncoming =
                                    child.key == currentCarouselKey;
                                final slideAnimation = isIncoming
                                    ? Tween<Offset>(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero,
                                      ).animate(animation)
                                    : Tween<Offset>(
                                        begin: Offset.zero,
                                        end: const Offset(-1, 0),
                                      ).animate(ReverseAnimation(animation));
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slideAnimation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Tooltip(
                                key: currentCarouselKey,
                                message: currentLink.tip,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: currentLink.onTap,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        currentLink.iconWidget,
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 240),
                                          child: Text(
                                            currentLink.tip,
                                            style: TextStyle(
                                                fontFamily: fontFamily),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Row(
                            key: const ValueKey('parallel_mode'),
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: linkItems
                                .map(
                                  (item) => _buildLinkIcon(
                                    iconWidget: item.iconWidget,
                                    tip: item.tip,
                                    onTap: item.onTap,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                myController.checkUpdate();
              },
              leading: const Icon(Icons.update),
              title: Text('版本', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('点击检查更新', style: TextStyle(fontFamily: fontFamily)),
              value:
                  Text(Api.version, style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/plugin/');
              },
              leading: const Icon(Icons.extension),
              title: Text('规则管理', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/player');
              },
              leading: const Icon(Icons.display_settings_rounded),
              title: Text('播放设置', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/danmaku/');
              },
              leading: const Icon(Icons.subtitles_rounded),
              title: Text('弹幕设置', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/keyboard');
              },
              leading: const Icon(Icons.keyboard_rounded),
              title: Text('按键映射', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/proxy');
              },
              leading: const Icon(Icons.vpn_key_rounded),
              title: Text('网络设置', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/download-settings');
              },
              leading: const Icon(Icons.download),
              title: Text('下载设置', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/webdav/');
              },
              leading: const Icon(Icons.cloud),
              title: Text('同步设置', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/theme');
              },
              leading: const Icon(Icons.palette_rounded),
              title: Text('外观和行为', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
      ],
    );
  }
}

class _MyLinkItem {
  const _MyLinkItem({
    required this.tip,
    required this.iconWidget,
    required this.onTap,
  });

  final String tip;
  final Widget iconWidget;
  final VoidCallback onTap;
}
