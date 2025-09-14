import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  Box setting = GStorage.setting;
  late double defaultPlaySpeed;
  late int defaultAspectRatioType;
  late bool hAenable;
  late bool androidEnableOpenSLES;
  late bool lowMemoryMode;
  late bool playResume;
  late bool showPlayerError;
  late bool privateMode;
  late bool playerDebugMode;
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    defaultPlaySpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    defaultAspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    privateMode = setting.get(SettingBoxKey.privateMode, defaultValue: false);
    showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void updateDefaultPlaySpeed(double speed) {
    setting.put(SettingBoxKey.defaultPlaySpeed, speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  void updateDefaultAspectRatioType(int type) {
    setting.put(SettingBoxKey.defaultAspectRatioType, type);
    setState(() {
      defaultAspectRatioType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('播放设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: const Text('播放器默认状态'),
              tiles: [
                SettingsTile.navigation(
                  title: const Text('超分辨率'),
                  value: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 1, label: Text('关闭')),
                      ButtonSegment<int>(value: 2, label: Text('效率')),
                      ButtonSegment<int>(value: 3, label: Text('质量')),
                    ],
                    selected: <int>{setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1)},
                    onSelectionChanged: (Set<int> selected) {
                      if (selected.isNotEmpty) {
                        setting.put(SettingBoxKey.defaultSuperResolutionType, selected.first);
                        // 自动启用硬件解码
                        if (selected.first == 2 || selected.first == 3) {
                          if (!hAenable) {
                            hAenable = true;
                            setting.put(SettingBoxKey.hAenable, true);
                          }
                        }
                        setState(() {});
                      }
                    },
                  ),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {},
                  title: const Text('画面尺寸'),
                  value: SegmentedButton<int>(
                    segments: [
                      for (final entry in aspectRatioTypeMap.entries)
                        ButtonSegment<int>(
                          value: entry.key,
                          label: Text(entry.value),
                        ),
                    ],
                    selected: <int>{defaultAspectRatioType},
                    onSelectionChanged: (Set<int> selected) {
                      if (selected.isNotEmpty) {
                        updateDefaultAspectRatioType(selected.first);
                      }
                    },
                  ),
                ),
                SettingsTile(
                  title: const Text('倍速'),
                  description: Slider(
                    value: defaultPlaySpeed,
                    min: 0.25,
                    max: 3,
                    divisions: 11,
                    label: '${defaultPlaySpeed}x',
                    onChanged: (value) {
                      updateDefaultPlaySpeed(
                          double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  enabled: setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1) == 1,
                  onToggle: (value) async {
                    // 只有超分辨率关闭时才允许切换
                    if (setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1) == 1) {
                      hAenable = value ?? !hAenable;
                      await setting.put(SettingBoxKey.hAenable, hAenable);
                      setState(() {});
                    }
                  },
                  title: const Text('硬件解码'),
                  initialValue: hAenable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/player/decoder');
                  },
                  title: const Text('硬件解码器'),
                  description: const Text('仅在硬件解码启用时生效'),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    lowMemoryMode = value ?? !lowMemoryMode;
                    await setting.put(
                        SettingBoxKey.lowMemoryMode, lowMemoryMode);
                    setState(() {});
                  },
                  title: const Text('低内存模式'),
                  description: const Text('禁用高级缓存以减少内存占用'),
                  initialValue: lowMemoryMode,
                ),
                if (Platform.isAndroid) ...[
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      androidEnableOpenSLES = value ?? !androidEnableOpenSLES;
                      await setting.put(SettingBoxKey.androidEnableOpenSLES,
                          androidEnableOpenSLES);
                      setState(() {});
                    },
                    title: const Text('低延迟音频'),
                    description: const Text('启用OpenSLES音频输出以降低延时'),
                    initialValue: androidEnableOpenSLES,
                  ),
                ],
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playResume = value ?? !playResume;
                    await setting.put(SettingBoxKey.playResume, playResume);
                    setState(() {});
                  },
                  title: const Text('自动跳转'),
                  description: const Text('跳转到上次播放位置'),
                  initialValue: playResume,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showPlayerError = value ?? !showPlayerError;
                    await setting.put(
                        SettingBoxKey.showPlayerError, showPlayerError);
                    setState(() {});
                  },
                  title: const Text('错误提示'),
                  description: const Text('显示播放器内部错误提示'),
                  initialValue: showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDebugMode = value ?? !playerDebugMode;
                    await setting.put(
                        SettingBoxKey.playerDebugMode, playerDebugMode);
                    setState(() {});
                  },
                  title: const Text('调试模式'),
                  description: const Text('记录播放器内部日志'),
                  initialValue: playerDebugMode,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    privateMode = value ?? !privateMode;
                    await setting.put(SettingBoxKey.privateMode, privateMode);
                    setState(() {});
                  },
                  title: const Text('隐身模式'),
                  description: const Text('不保留观看记录'),
                  initialValue: privateMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
