import 'package:card_settings_ui/list/settings_list.dart';
import 'package:card_settings_ui/section/settings_section.dart';
import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  Box setting = GStorage.setting;
  late bool showRating;
  late bool enablePredictiveBackGesture;
  late String defaultPage;
  final MenuController defaultPageMenuController = MenuController();

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': '推荐',
    '/tab/timeline/': '时间表',
    '/tab/collect/': '追番',
    '/tab/my/': '我的',
  };

  @override
  void initState() {
    super.initState();
    showRating = setting.get(SettingBoxKey.showRating, defaultValue: true);
    enablePredictiveBackGesture = setting.get(
      SettingBoxKey.enablePredictiveBackGesture,
      defaultValue: true,
    );
    defaultPage = setting.get(SettingBoxKey.defaultStartupPage,
        defaultValue: '/tab/popular/');
  }

  void updateDefaultPage(String page) {
    setting.put(SettingBoxKey.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final ThemeProvider themeProvider =
        Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      appBar: SysAppBar(
        title: Text('界面设置'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(tiles: [
            SettingsTile.navigation(
              onPressed: (_) async {
                if (defaultPageMenuController.isOpen) {
                  defaultPageMenuController.close();
                } else {
                  defaultPageMenuController.open();
                }
              },
              title: Text('启动界面设置', style: TextStyle(fontFamily: fontFamily)),
              description: Text('设置应用开启时的默认页面',
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: defaultPageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    defaultPageMap[defaultPage] ?? '推荐',
                    style: TextStyle(fontFamily: fontFamily),
                  );
                },
                menuChildren: [
                  for (final entry in defaultPageMap.entries)
                    MenuItemButton(
                      requestFocusOnHover: false,
                      onPressed: () => updateDefaultPage(entry.key),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: entry.key == defaultPage
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                enablePredictiveBackGesture =
                    value ?? !enablePredictiveBackGesture;
                await setting.put(
                  SettingBoxKey.enablePredictiveBackGesture,
                  enablePredictiveBackGesture,
                );
                // Trigger app-level theme rebuild so page transition changes apply immediately.
                themeProvider.setThemeMode(themeProvider.themeMode);
                setState(() {});
              },
              title: Text('预测性返回手势', style: TextStyle(fontFamily: fontFamily)),
              description: Text(
                '关闭后将恢复旧版返回行为',
                style: TextStyle(fontFamily: fontFamily),
              ),
              initialValue: enablePredictiveBackGesture,
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
          ]),
        ],
      ),
    );
  }
}
