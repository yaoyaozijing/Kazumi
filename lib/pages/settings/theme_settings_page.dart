import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:provider/provider.dart';

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
  final PopularController popularController = Modular.get<PopularController>();
  late final ThemeProvider themeProvider;
  final MenuController menuController = MenuController();

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
        brightness: Brightness.dark,
        colorSchemeSeed: color,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
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
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('外观设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  title: const Text('外观'),
                  value: SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'system',
                        label: defaultThemeMode == 'system'
                            ? const Center(child: Text('系统'))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.brightness_auto_rounded, size: 18),
                                  SizedBox(width: 4),
                                  Text('系统'),
                                ],
                              ),
                      ),
                      ButtonSegment<String>(
                        value: 'light',
                        label: defaultThemeMode == 'light'
                            ? const Center(child: Text('浅色'))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.light_mode_rounded, size: 18),
                                  SizedBox(width: 4),
                                  Text('浅色'),
                                ],
                              ),
                      ),
                      ButtonSegment<String>(
                        value: 'dark',
                        label: defaultThemeMode == 'dark'
                            ? const Center(child: Text('深色'))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.dark_mode_rounded, size: 18),
                                  SizedBox(width: 4),
                                  Text('深色'),
                                ],
                              ),
                      ),
                    ],
                    selected: <String>{defaultThemeMode},
                    onSelectionChanged: (Set<String> selected) {
                      if (selected.isNotEmpty) {
                        updateTheme(selected.first);
                      }
                    },
                  ),
                ),
                SettingsTile.navigation(
                  enabled: !useDynamicColor,
                  title: const Text('配色方案'),
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: Utils.isDesktop() ? 8 : 0,
                          children: [
                            ...colorThemeTypes.map((e) {
                              final index = colorThemeTypes.indexOf(e);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (index == 0) {
                                      resetTheme();
                                    } else {
                                      setTheme(e['color']);
                                    }
                                  });
                                },
                                child: Column(
                                  children: [
                                    PaletteCard(
                                      color: e['color'],
                                      selected: (e['color'].value.toRadixString(16) == defaultThemeColor ||
                                          (defaultThemeColor == 'default' && index == 0)),
                                    ),
                                    Text(e['label']),
                                  ],
                                ),
                              );
                            })
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsTile.switchTile(
                  enabled: !Platform.isIOS,
                  onToggle: (value) async {
                    useDynamicColor = value ?? !useDynamicColor;
                    await setting.put(
                        SettingBoxKey.useDynamicColor, useDynamicColor);
                    themeProvider.setDynamic(useDynamicColor);
                    setState(() {});
                  },
                  title: const Text('动态配色'),
                  description: const Text('仅支持安卓12及以上和桌面平台'),
                  initialValue: useDynamicColor,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    oledEnhance = value ?? !oledEnhance;
                    await setting.put(SettingBoxKey.oledEnhance, oledEnhance);
                    updateOledEnhance();
                    setState(() {});
                  },
                  title: const Text('OLED优化'),
                  description: const Text('深色模式下使用纯黑背景'),
                  initialValue: oledEnhance,
                ),
              ],
            ),
            if (Utils.isDesktop())
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      showWindowButton = value ?? !showWindowButton;
                      await setting.put(
                          SettingBoxKey.showWindowButton, showWindowButton);
                      setState(() {});
                    },
                    title: const Text('使用系统标题栏'),
                    description: const Text('重启应用生效'),
                    initialValue: showWindowButton,
                  ),
                ],
              ),
            if (Platform.isAndroid)
              SettingsSection(
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      Modular.to.pushNamed('/settings/theme/display');
                    },
                    title: const Text('屏幕帧率'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
