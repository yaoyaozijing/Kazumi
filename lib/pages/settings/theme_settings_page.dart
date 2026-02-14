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
  final PopularController popularController = Modular.get<PopularController>();
  late final ThemeProvider themeProvider;
  final MenuController menuController = MenuController();
  final exitBehaviorTitles = <String>['退出', '进托盘', '询问'];
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
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
    defaultThemeColor = color?.value.toRadixString(16) ?? 'default';
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
                  title: Text('OLED优化', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('深色模式下使用纯黑背景', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: oledEnhance,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    useSystemFont = value ?? !useSystemFont;
                    await setting.put(SettingBoxKey.useSystemFont, useSystemFont);
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
                  title: Text('使用系统字体', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('关闭后使用 MI Sans 字体', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: useSystemFont,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showRating = value ?? !showRating;
                    await setting.put(SettingBoxKey.showRating, showRating);
                    setState(() {});
                  },
                  title: Text('显示评分', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('关闭后将在概览中隐藏评分信息', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showRating,
                ),
              ],
              bottomInfo: Text('动态配色仅支持安卓12及以上和桌面平台', style: TextStyle(fontFamily: fontFamily)),
            ),

            if (Utils.isDesktop())
              SettingsSection(
                title: Text('桌面端设置', style: TextStyle(fontFamily: fontFamily)),
                tiles: [
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      showWindowButton = value ?? !showWindowButton;
                      await setting.put(
                          SettingBoxKey.showWindowButton, showWindowButton);
                      setState(() {});
                    },
                    title: Text('使用系统标题栏', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('重启应用生效', style: TextStyle(fontFamily: fontFamily)),
                    initialValue: showWindowButton,
                  ),
                  SettingsTileSegmentedButton<int>(
                    title: Text('关闭窗口时', style: TextStyle(fontFamily: fontFamily)),
                    segments: [
                      for (int i = 0; i < exitBehaviorTitles.length; i++)
                        ButtonSegment<int>(
                          value: i,
                          label: Text(exitBehaviorTitles[i]),
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
            if (Platform.isAndroid)
              SettingsSection(
                title: Text('移动端设置', style: TextStyle(fontFamily: fontFamily)),
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      Modular.to.pushNamed('/settings/theme/display');
                    },
                    title: Text('屏幕帧率', style: TextStyle(fontFamily: fontFamily)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
