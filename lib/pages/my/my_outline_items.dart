import 'package:flutter/material.dart';

import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';

typedef PageBuilder = Widget Function();

class OutlineTile {
  final String title;
  final String route;
  final IconData? icon;
  final PageBuilder pageBuilder;

  const OutlineTile({
    required this.title,
    required this.route,
    required this.pageBuilder,
    this.icon,
  });
}

class OutlineSection {
  final String? title; // 可以为 null 或 empty
  final List<OutlineTile> tiles;

  const OutlineSection({this.title, required this.tiles});
}
List<OutlineSection> myOutlineSections = [
  OutlineSection(
    title: null, // 顶部 logo 区块
    tiles: [
      OutlineTile(
        title: '关于', // 特殊处理
        route: '/settings/about/',
        pageBuilder: () => AboutPage(),
        icon: null,
      ),
      OutlineTile(
        title: '关于Kazumi',
        route: '/settings/about/',
        pageBuilder: () => AboutPage(),
        icon: Icons.info_outline_rounded,
      ),
    ],
  ),
  OutlineSection(
    title: '历史、下载和规则',
    tiles: [
      OutlineTile(
        title: '播放历史',
        route: '/settings/history/',
        pageBuilder: () => HistoryPage(),
        icon: Icons.history_rounded,
      ),
      OutlineTile(
        title: '下载记录',
        route: '/settings/download/',
        pageBuilder: () => DownloadPage(),
        icon: Icons.download_rounded,
      ),
      OutlineTile(
        title: '下载选项',
        route: '/settings/download-settings',
        pageBuilder: () => DownloadSettingsPage(),
        icon: Icons.settings_rounded,
      ),
      OutlineTile(
        title: '规则管理',
        route: '/settings/plugin/',
        pageBuilder: () => PluginViewPage(),
        icon: Icons.extension,
      ),
    ],
  ),
  OutlineSection(
    title: '播放器设置',
    tiles: [
      OutlineTile(
        title: '播放器',
        route: '/settings/player',
        pageBuilder: () => PlayerSettingsPage(),
        icon: Icons.display_settings_rounded,
      ),
      OutlineTile(
        title: '弹幕',
        route: '/settings/danmaku/',
        pageBuilder: () => DanmakuSettingsPage(),
        icon: Icons.subtitles_rounded,
      ),
      OutlineTile(
        title: '快捷键',
        route: '/settings/keyboard',
        pageBuilder: () => KeyboardSettingsPage(),
        icon: Icons.keyboard_rounded,
      ),
      OutlineTile(
        title: '网络代理',
        route: '/settings/proxy',
        pageBuilder: () => ProxySettingsPage(),
        icon: Icons.vpn_key_rounded,
      ),
    ],
  ),
  OutlineSection(
    title: '应用与外观',
    tiles: [
      OutlineTile(
        title: '外观和行为',
        route: '/settings/theme',
        pageBuilder: () => ThemeSettingsPage(),
        icon: Icons.palette_rounded,
      ),
      OutlineTile(
        title: '同步',
        route: '/settings/webdav/',
        pageBuilder: () => WebDavSettingsPage(),
        icon: Icons.cloud,
      ),
    ],
  ),
];
