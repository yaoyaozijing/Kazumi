import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/utils/setting_tiles.dart';
import 'package:kazumi/bean/card/color_scheme_seloctor_card.dart';
import 'package:kazumi/utils/settings_route.dart';
import 'package:path_provider/path_provider.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  Box setting = GStorage.setting;
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  late bool oledEnhance;
  late bool useDynamicColor;
  late bool showWindowButton;
  late bool useSystemFont;
  late bool showRating;
  late bool autoUpdate;
  late bool hideBuiltInCollectFolders;
  late bool foldableOptimization;
  late String defaultPage;
  late String defaultCollectView;
  double _cacheSizeMB = -1;
  final PopularController popularController = Modular.get<PopularController>();
  late final ThemeProvider themeProvider;
  final MenuController menuController = MenuController();
  late int exitBehavior =
      setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);

  @override
  void initState() {
    super.initState();
    defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    useDynamicColor =
        setting.get(SettingBoxKey.useDynamicColor, defaultValue: false);
    showWindowButton =
        setting.get(SettingBoxKey.showWindowButton, defaultValue: false);
    useSystemFont =
        setting.get(SettingBoxKey.useSystemFont, defaultValue: false);
    showRating = setting.get(SettingBoxKey.showRating, defaultValue: true);
    autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    hideBuiltInCollectFolders = setting.get(
      SettingBoxKey.collectHideBuiltInFolders,
      defaultValue: false,
    );
    foldableOptimization = setting.get(
      SettingBoxKey.foldableOptimization,
      defaultValue: false,
    );
    defaultPage = setting.get(SettingBoxKey.defaultStartupPage,
        defaultValue: '/tab/popular/');
    defaultCollectView =
        setting.get(SettingBoxKey.collectDefaultView, defaultValue: 'collect');
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _getCacheSize();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void setTheme(Color? color) {
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: themeProvider.currentFontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: color,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
          fontFamily: themeProvider.currentFontFamily,
          brightness: Brightness.light,
          colorSchemeSeed: color,
          progressIndicatorTheme: progressIndicatorTheme2024,
          sliderTheme: sliderTheme2024,
          pageTransitionsTheme: pageTransitionsTheme2024),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
    );
    defaultThemeColor = color?.toARGB32().toRadixString(16) ?? 'default';
    setting.put(SettingBoxKey.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: themeProvider.currentFontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
          fontFamily: themeProvider.currentFontFamily,
          brightness: Brightness.light,
          colorSchemeSeed: Colors.green,
          progressIndicatorTheme: progressIndicatorTheme2024,
          sliderTheme: sliderTheme2024,
          pageTransitionsTheme: pageTransitionsTheme2024),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
    );
    defaultThemeColor = 'default';
    setting.put(SettingBoxKey.themeColor, 'default');
  }

  void updateTheme(String theme) async {
    if (theme == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark);
    }
    if (theme == 'light') {
      themeProvider.setThemeMode(ThemeMode.light);
    }
    if (theme == 'system') {
      themeProvider.setThemeMode(ThemeMode.system);
    }
    await setting.put(SettingBoxKey.themeMode, theme);
    setState(() {
      defaultThemeMode = theme;
    });
  }

  void updateOledEnhance() {
    dynamic color;
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    if (defaultThemeColor == 'default') {
      color = Colors.green;
    } else {
      color = Color(int.parse(defaultThemeColor, radix: 16));
    }
    setTheme(color);
  }

  void updateDefaultPage(String page) {
    setting.put(SettingBoxKey.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  void updateDefaultCollectView(String view) {
    setting.put(SettingBoxKey.collectDefaultView, view);
    setState(() {
      defaultCollectView = view;
    });
  }

  Future<Directory> _getCacheDir() async {
    Directory tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/libCachedImageData');
  }

  Future<void> _getCacheSize() async {
    Directory cacheDir = await _getCacheDir();

    if (await cacheDir.exists()) {
      int totalSizeBytes = await _getTotalSizeOfFilesInDir(cacheDir);
      double totalSizeMB = (totalSizeBytes / (1024 * 1024));

      if (mounted) {
        setState(() {
          _cacheSizeMB = totalSizeMB;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cacheSizeMB = 0.0;
        });
      }
    }
  }

  Future<int> _getTotalSizeOfFilesInDir(final Directory directory) async {
    final List<FileSystemEntity> children = directory.listSync();
    int total = 0;

    try {
      for (final FileSystemEntity child in children) {
        if (child is File) {
          final int length = await child.length();
          total += length;
        } else if (child is Directory) {
          total += await _getTotalSizeOfFilesInDir(child);
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    final Directory libCacheDir = await _getCacheDir();
    await libCacheDir.delete(recursive: true);
    _getCacheSize();
  }

  void _showCacheDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('缓存管理'),
          content: const Text('缓存为番剧封面, 清除后加载时需要重新下载,确认要清除缓存吗?'),
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
                try {
                  _clearCache();
                } catch (_) {}
                KazumiDialog.dismiss();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('外观和行为')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('外观', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTileSegmentedButton<String>(
                  title: Text(
                    '外观',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  segments: const [
                    ButtonSegment<String>(
                      value: 'system',
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('自动'),
                    ),
                    ButtonSegment<String>(
                      value: 'light',
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('浅色'),
                    ),
                    ButtonSegment<String>(
                      value: 'dark',
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('深色'),
                    ),
                  ],
                  selected: {defaultThemeMode},
                  onSelectionChanged: (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      final newMode = newSelection.first;

                      updateTheme(newMode);
                      setting.put(SettingBoxKey.themeMode, newMode);

                      setState(() {});
                    }
                  },
                ),
                SettingsTile(
                  title: Text(
                    '配色方案',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  description: SizedBox(
                    height: 170,
                    child: ColorSchemeSelector(
                      colorThemes: colorThemeTypes,
                      defaultThemeColor: defaultThemeColor,
                      useDynamicColor: useDynamicColor,
                      resetTheme: resetTheme,
                      setTheme: setTheme,
                      setDynamic: (value) async {
                        useDynamicColor = value;
                        await setting.put(SettingBoxKey.useDynamicColor, value);
                        themeProvider.setDynamic(value);
                      },
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    oledEnhance = value ?? !oledEnhance;
                    await setting.put(SettingBoxKey.oledEnhance, oledEnhance);
                    updateOledEnhance();
                    setState(() {});
                  },
                  title:
                      Text('OLED优化', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('深色模式下使用纯黑背景',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: oledEnhance,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    useSystemFont = value ?? !useSystemFont;
                    await setting.put(
                        SettingBoxKey.useSystemFont, useSystemFont);
                    themeProvider.setFontFamily(useSystemFont);
                    dynamic color;
                    if (defaultThemeColor == 'default') {
                      color = Colors.green;
                    } else {
                      color = Color(int.parse(defaultThemeColor, radix: 16));
                    }
                    setTheme(color);
                    setState(() {});
                  },
                  title:
                      Text('使用系统字体', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('关闭后使用 MI Sans 字体',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: useSystemFont,
                ),
                if (Utils.isDesktop())
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      showWindowButton = value ?? !showWindowButton;
                      await setting.put(
                          SettingBoxKey.showWindowButton, showWindowButton);
                      setState(() {});
                    },
                    title: Text('使用系统标题栏',
                        style: TextStyle(fontFamily: fontFamily)),
                    description: Text('重启应用生效',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: showWindowButton,
                  ),
                if (Platform.isAndroid)
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      pushSettingsRoute('/settings/theme/display');
                    },
                    title:
                        Text('屏幕帧率', style: TextStyle(fontFamily: fontFamily)),
                  ),
              ],
              bottomInfo: Text('动态配色仅支持安卓12及以上和桌面平台',
                  style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsSection(
              title: Text('行为', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTileSegmentedButton<String>(
                  title: Text('启动界面', style: TextStyle(fontFamily: fontFamily)),
                  segments: const [
                    ButtonSegment<String>(
                      value: '/tab/popular/',
                      label: Text('推荐'),
                    ),
                    ButtonSegment<String>(
                      value: '/tab/timeline/',
                      label: Text('时间表'),
                    ),
                    ButtonSegment<String>(
                      value: '/tab/collect/',
                      label: Text('收藏夹'),
                    ),
                    ButtonSegment<String>(
                      value: '/tab/my/',
                      label: Text('设置'),
                    ),
                  ],
                  selected: {defaultPage},
                  onSelectionChanged: (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      updateDefaultPage(newSelection.first);
                    }
                  },
                ),
                SettingsTileSegmentedButton<String>(
                  title:
                      Text('收藏夹默认页面', style: TextStyle(fontFamily: fontFamily)),
                  segments: const [
                    ButtonSegment<String>(
                      value: 'collect',
                      label: Text('收藏夹'),
                    ),
                    ButtonSegment<String>(
                      value: 'history',
                      label: Text('历史'),
                    ),
                    ButtonSegment<String>(
                      value: 'download',
                      label: Text('下载'),
                    ),
                  ],
                  selected: {defaultCollectView},
                  onSelectionChanged: (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      updateDefaultCollectView(newSelection.first);
                    }
                  },
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    hideBuiltInCollectFolders =
                        value ?? !hideBuiltInCollectFolders;
                    await setting.put(
                      SettingBoxKey.collectHideBuiltInFolders,
                      hideBuiltInCollectFolders,
                    );
                    setState(() {});
                  },
                  title:
                      Text('隐藏内建收藏夹', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '隐藏原本追番类型，但数据不会丢失',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  initialValue: hideBuiltInCollectFolders,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    foldableOptimization = value ?? !foldableOptimization;
                    await setting.put(
                      SettingBoxKey.foldableOptimization,
                      foldableOptimization,
                    );
                    setState(() {});
                  },
                  title:
                      Text('折叠屏优化', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '开启后双栏始终 1:1，主导航固定底栏',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  initialValue: foldableOptimization,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showRating = value ?? !showRating;
                    await setting.put(SettingBoxKey.showRating, showRating);
                    setState(() {});
                  },
                  title: Text('显示评分', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('关闭后将在概览中隐藏评分信息',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showRating,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    autoUpdate = value ?? !autoUpdate;
                    await setting.put(SettingBoxKey.autoUpdate, autoUpdate);
                    setState(() {});
                  },
                  title:
                      Text('自动检查更新', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: autoUpdate,
                ),
                if (Utils.isDesktop())
                  SettingsTileSegmentedButton<int>(
                    title:
                        Text('关闭时', style: TextStyle(fontFamily: fontFamily)),
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('退出'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('进托盘'),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        label: Text('询问'),
                      ),
                    ],
                    selected: {exitBehavior},
                    onSelectionChanged: (Set<int> newSelection) {
                      if (newSelection.isNotEmpty) {
                        exitBehavior = newSelection.first;
                        setting.put(SettingBoxKey.exitBehavior, exitBehavior);
                        setState(() {});
                      }
                    },
                    showSelectedIcon: false,
                  ),
              ],
            ),
            SettingsSection(
              title: Text('其他', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    pushSettingsRoute('/settings/logs');
                  },
                  title: Text('错误日志', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    _showCacheDialog();
                  },
                  title: Text('清除缓存', style: TextStyle(fontFamily: fontFamily)),
                  value: _cacheSizeMB == -1
                      ? Text('统计中...', style: TextStyle(fontFamily: fontFamily))
                      : Text('${_cacheSizeMB.toStringAsFixed(2)}MB',
                          style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
