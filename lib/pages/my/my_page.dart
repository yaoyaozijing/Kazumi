import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const double _kTwoPaneMinWidth = 700;
  static const double _kLeftPaneWidth = 300;
  static const Duration _kPaneSwitchDuration = Duration(milliseconds: 480);
  late NavigationBarState navigationBarState;
  bool _wasAtSecondLevel = false;

  bool _isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _kTwoPaneMinWidth;

  bool _isInSettingsDetail() => Modular.to.path.startsWith('/tab/my/settings');

  bool _isAtSecondLevel(String path) {
    const prefix = '/tab/my/settings';
    if (!path.startsWith(prefix)) {
      return false;
    }
    final segments = path
        .substring(prefix.length)
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    return segments.length == 1;
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
    final atSecondLevel = _isAtSecondLevel(Modular.to.path);
    if (atSecondLevel && !_wasAtSecondLevel) {
      SysAppBar.notifyLeadingRefresh();
    }
    _wasAtSecondLevel = atSecondLevel;
    setState(() {});
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
    _wasAtSecondLevel = _isAtSecondLevel(Modular.to.path);
    Modular.to.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            late double leftX;
            late double leftWidth;
            late double rightX;
            late double rightWidth;

            if (isTwoPane) {
              if (isInDetail) {
                leftX = 0;
                leftWidth = _kLeftPaneWidth;
                rightX = _kLeftPaneWidth;
                rightWidth =
                    (totalWidth - _kLeftPaneWidth).clamp(0.0, totalWidth);
              } else {
                leftX = 0;
                leftWidth = totalWidth;
                rightX = totalWidth;
                rightWidth = totalWidth;
              }
            } else {
              leftWidth = totalWidth;
              rightWidth = totalWidth;
              leftX = isInDetail ? -totalWidth : 0;
              rightX = isInDetail ? 0 : totalWidth;
            }

            final canTapLeft = isTwoPane ? true : !isInDetail;
            final canTapRight = isInDetail;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: _kPaneSwitchDuration,
                  curve: Curves.easeOutCubic,
                  left: leftX,
                  top: 0,
                  bottom: 0,
                  width: leftWidth,
                  child: IgnorePointer(
                    ignoring: !canTapLeft,
                    child: _buildSettingsList(context, fontFamily),
                  ),
                ),
                AnimatedPositioned(
                  duration: _kPaneSwitchDuration,
                  curve: Curves.easeOutCubic,
                  left: rightX,
                  top: 0,
                  bottom: 0,
                  width: rightWidth,
                  child: IgnorePointer(
                    ignoring: !canTapRight,
                    child: _buildDetailPane(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailPane(BuildContext context) {
    return RouterOutlet();
  }

  Widget _buildSettingsList(BuildContext context, String? fontFamily) {
    return SettingsList(
      maxWidth: 1000,
      sections: [
        SettingsSection(
          title: const SizedBox.shrink(),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/about/');
              },
              title: Center(
                child: Image.asset(
                  'assets/images/mypage_logo.png',
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/about/');
              },
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('关于Kazumi', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('播放历史与视频源', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/history/');
              },
              leading: const Icon(Icons.history_rounded),
              title: Text('历史记录', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('查看播放历史记录', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/download/');
              },
              leading: const Icon(Icons.download_rounded),
              title: Text('下载管理', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('查看和管理离线下载', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/download-settings');
              },
              leading: const Icon(Icons.settings_rounded),
              title: Text('下载设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('配置下载并发数等参数', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/plugin/');
              },
              leading: const Icon(Icons.extension),
              title: Text('规则管理', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('管理番剧资源规则', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('播放器设置', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/player');
              },
              leading: const Icon(Icons.display_settings_rounded),
              title: Text('播放设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('设置播放器相关参数', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/danmaku/');
              },
              leading: const Icon(Icons.subtitles_rounded),
              title: Text('弹幕设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('设置弹幕相关参数', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/keyboard');
              },
              leading: const Icon(Icons.keyboard_rounded),
              title: Text('操作设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('设置播放器按键映射', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/proxy');
              },
              leading: const Icon(Icons.vpn_key_rounded),
              title: Text('代理设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('配置HTTP代理', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('应用与外观', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/theme');
              },
              leading: const Icon(Icons.palette_rounded),
              title: Text('外观和行为', style: TextStyle(fontFamily: fontFamily)),
              description: Text('设置应用主题、刷新率和行为',
                  style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) {
                _openSettings('/tab/my/settings/webdav/');
              },
              leading: const Icon(Icons.cloud),
              title: Text('同步设置', style: TextStyle(fontFamily: fontFamily)),
              description:
                  Text('设置同步参数', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
      ],
    );
  }
}
