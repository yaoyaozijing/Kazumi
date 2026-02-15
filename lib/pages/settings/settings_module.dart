import 'package:kazumi/pages/settings/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/about/about_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_module.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_module.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/renderer_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_module.dart';
import 'package:kazumi/pages/webdav_editor/webdav_module.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/download/download_page_module.dart';

class SettingsModule extends Module {
  @override
  void routes(r) {
    r.child(
      "/theme",
      child: (_) => const ThemeSettingsPage(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/theme/display",
      child: (_) => const SetDisplayMode(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/keyboard",
      child: (_) => const KeyboardSettingsPage(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/player",
      child: (_) => const PlayerSettingsPage(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/player/decoder",
      child: (_) => const DecoderSettings(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/player/renderer",
      child: (_) => const RendererSettings(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/proxy",
      module: ProxyModule(),
      transition: TransitionType.defaultTransition,
    );
    // r.child("/other", child: (_) => const OtherSettingsPage());
    r.module(
      "/webdav",
      module: WebDavModule(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/about",
      module: AboutModule(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/plugin",
      module: PluginModule(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/history",
      module: HistoryModule(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/danmaku",
      module: DanmakuModule(),
      transition: TransitionType.defaultTransition,
    );
    r.module(
      "/download",
      module: DownloadModule(),
      transition: TransitionType.defaultTransition,
    );
    r.child(
      "/download-settings",
      child: (_) => const DownloadSettingsPage(),
      transition: TransitionType.defaultTransition,
    );
  }
}
