import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/my/my_state.dart';


class MyOutline extends StatelessWidget {
  const MyOutline({
    super.key,
    this.onSelect,
  });

  final ValueChanged<String>? onSelect;


  void _handleTap(BuildContext context, String route) {
    if (onSelect != null) {
      onSelect!(route);
    } else {
      Provider.of<MyState>(context, listen: false).open(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return SettingsList(
      maxWidth: 1000,
      sections: [
        SettingsSection(
          title: Text('历史、下载和规则', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/history/'),
              leading: const Icon(Icons.history_rounded),
              title: Text('播放历史', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/download/'),
              leading: const Icon(Icons.download_rounded),
              title: Text('下载记录', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) =>
                  _handleTap(context, '/settings/download-settings'),
              leading: const Icon(Icons.settings_rounded),
              title: Text('下载选项', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/plugin/'),
              leading: const Icon(Icons.extension),
              title: Text('资源规则', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('播放器设置', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/player'),
              leading: const Icon(Icons.display_settings_rounded),
              title: Text('播放器', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/danmaku/'),
              leading: const Icon(Icons.subtitles_rounded),
              title: Text('弹幕', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/keyboard'),
              leading: const Icon(Icons.keyboard_rounded),
              title: Text('快捷键', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/proxy'),
              leading: const Icon(Icons.vpn_key_rounded),
              title: Text('网络代理', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('应用与外观', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/theme'),
              leading: const Icon(Icons.palette_rounded),
              title: Text('外观和行为', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/webdav/'),
              leading: const Icon(Icons.cloud),
              title: Text('同步', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
        SettingsSection(
          title: Text('其他', style: TextStyle(fontFamily: fontFamily)),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, '/settings/about/'),
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('关于', style: TextStyle(fontFamily: fontFamily)),
            ),
          ],
        ),
      ],
    );
  }
}
