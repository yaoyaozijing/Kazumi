import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/my/my_outline.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_state.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/renderer_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late NavigationBarState navigationBarState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }

    final myState = Provider.of<MyState>(context, listen: false);

    // 窄屏 detail -> 返回 outline
    if (myState.hasDetail &&
        MediaQuery.of(context).size.width < 900) {
      myState.clear();
      return;
    }

    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackPressed(context);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Consumer<MyState>(
              builder: (context, state, _) {
                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: MyOutline(
                          onSelect: state.open, // ✅ 修复 select 错误
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      const Expanded(
                        child: _MyDetailPane(),
                      ),
                    ],
                  );
                }

                if (state.hasDetail) {
                  return const _MyDetailPane();
                }

                return const MyOutline();
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyDetailPane extends StatelessWidget {
  const _MyDetailPane();

  @override
  Widget build(BuildContext context) {
    final route =
        Provider.of<MyState>(context).currentRoute;

    if (route == null) {
      return const Center(
        child: Text(
          '请选择左侧的设置项',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    switch (route) {
      // ===== 外观 =====
      case '/settings/theme':
        return const ThemeSettingsPage();
      case '/settings/theme/display':
        return const SetDisplayMode();

      // ===== 键盘 =====
      case '/settings/keyboard':
        return const KeyboardSettingsPage();

      // ===== 播放器 =====
      case '/settings/player':
        return const PlayerSettingsPage();
      case '/settings/player/decoder':
        return const DecoderSettings();
      case '/settings/player/renderer':
        return const RendererSettings();

      // ===== 弹幕 =====
      case '/settings/danmaku/':
        return const DanmakuSettingsPage();

      // ===== 下载 =====
      case '/settings/download/':
        return const DownloadPage();
      case '/settings/download-settings':
        return const DownloadSettingsPage();

      // ===== 历史 =====
      case '/settings/history/':
        return const HistoryPage();

      // ===== 代理 =====
      case '/settings/proxy':
        return const ProxySettingsPage();

      // ===== WebDAV =====
      case '/settings/webdav/':
        return const WebDavSettingsPage();

      // ===== 插件 =====
      case '/settings/plugin/':
        return const PluginViewPage();

      // ===== 关于 =====
      case '/settings/about/':
        return const AboutPage();

      default:
        return Center(
          child: Text(
            '未实现的设置页面：\n$route',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        );
    }
  }
}
