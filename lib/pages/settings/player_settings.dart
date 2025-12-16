import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/setting_tiles.dart';
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
  late bool playerDisableAnimations;
  late bool forceAdBlocker;
  late bool autoPlayNext;
  late int playerButtonSkipTime;
  late int playerArrowKeySkipTime;
  late int playerLogLevel;
  late int defaultSuperResolutionType;
  late bool superResolutionWarn;
  late String hardwareDecoder;

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
    autoPlayNext = setting.get(SettingBoxKey.autoPlayNext, defaultValue: true);
    playerDisableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);
    forceAdBlocker =
        setting.get(SettingBoxKey.forceAdBlocker, defaultValue: false);
    playerLogLevel = setting.get(SettingBoxKey.playerLogLevel, defaultValue: 2);

    playerButtonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    playerArrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);
    defaultSuperResolutionType = setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1);
    superResolutionWarn = setting.get(SettingBoxKey.superResolutionWarn, defaultValue: false);
    hardwareDecoder = setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
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

  void updatePlayerLogLevel(int level) {
    setting.put(SettingBoxKey.playerLogLevel, level);
    setState(() {
      playerLogLevel = level;
    });
  }

  void updateDefaultAspectRatioType(int type) {
    setting.put(SettingBoxKey.defaultAspectRatioType, type);
    setState(() {
      defaultAspectRatioType = type;
    });
  }

  void updateDefaultSuperResolutionType(int type) {
    setting.put(SettingBoxKey.defaultSuperResolutionType, type);
    setState(() {
      defaultSuperResolutionType = type;
    });
  }

  void updateSuperResolutionWarn(bool value) {
    setting.put(SettingBoxKey.superResolutionWarn, value);
    setState(() {
      superResolutionWarn = value;
    });
  }

  Future<void> updateButtonSkipTime() async {
    final int? newButtonSkipTime = await _showSkipTimeChangeDialog(
        title: '顶部按钮快进时长', initialValue: playerButtonSkipTime.toString());
    print('新设置的顶部按钮快进时长: $newButtonSkipTime');

    if (newButtonSkipTime != null &&
        newButtonSkipTime != playerButtonSkipTime) {
      setting.put(SettingBoxKey.buttonSkipTime, newButtonSkipTime);
      setState(() {
        playerButtonSkipTime = newButtonSkipTime;
      });
    }
  }

  Future<int?> _showSkipTimeChangeDialog(
      {required String title, required String initialValue}) async {
    return KazumiDialog.show<int>(builder: (context) {
      String input = "";
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
            ],
            decoration: InputDecoration(
              floatingLabelBehavior:
                  FloatingLabelBehavior.never, // 控制label的显示方式
              labelText: initialValue,
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final int? newValue = int.tryParse(input);

              if (newValue == null) {
                KazumiDialog.showToast(message: '请输入数字');
                return;
              }

              if (newValue <= 0) {
                KazumiDialog.showToast(message: '请输入大于0的数字');
                return;
              }
              // 以新设置的值弹出
              KazumiDialog.dismiss(popWith: newValue);
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
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
        appBar: const SysAppBar(title: Text('播放设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    hAenable = value ?? !hAenable;
                    await setting.put(SettingBoxKey.hAenable, hAenable);
                    setState(() {});
                  },
                  title: Text('硬件解码', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: hAenable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/player/decoder');
                    setState(() {
                      hardwareDecoder = setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
                    });
                  },
                  title: Text('硬件解码器', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('仅在硬件解码启用时生效', style: TextStyle(fontFamily: fontFamily)),
                  value: Text(hardwareDecoder, style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    lowMemoryMode = value ?? !lowMemoryMode;
                    await setting.put(
                        SettingBoxKey.lowMemoryMode, lowMemoryMode);
                    setState(() {});
                  },
                  title: Text('低内存模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('禁用高级缓存以减少内存占用', style: TextStyle(fontFamily: fontFamily)),
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
                    title: Text('低延迟音频', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('启用OpenSLES音频输出以降低延时', style: TextStyle(fontFamily: fontFamily)),
                    initialValue: androidEnableOpenSLES,
                  ),
                ],
                SettingsTileSegmentedButton<int>(
                  title: Text('超分辨率', style: TextStyle(fontFamily: fontFamily)),
                  segments: superResolutionTypeMap.entries.map((entry) => ButtonSegment<int>(value: entry.key, label: Text(entry.value))).toList(),
                  selected: {defaultSuperResolutionType},
                  onSelectionChanged: (Set<int> newSelection) {
                    updateDefaultSuperResolutionType(newSelection.first);
                  },
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    updateSuperResolutionWarn(value ?? !superResolutionWarn);
                  },
                  title: Text('关闭超分辨率提示', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('关闭每次启用超分辨率时的提示', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: superResolutionWarn,
                ),
              ],
              bottomInfo: Text('超分辨率基于Anime4K，需要启用硬件解码, 若启用硬件解码后仍然不生效, 尝试切换硬件解码器为 auto-copy', style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playResume = value ?? !playResume;
                    await setting.put(SettingBoxKey.playResume, playResume);
                    setState(() {});
                  },
                  title: Text('自动跳转', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('跳转到上次播放位置', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playResume,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    autoPlayNext = value ?? !autoPlayNext;
                    await setting.put(SettingBoxKey.autoPlayNext, autoPlayNext);
                    setState(() {});
                  },
                  title: Text('自动连播', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('当前视频播放完毕后自动播放下一集', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: autoPlayNext,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    forceAdBlocker = value ?? !forceAdBlocker;
                    await setting.put(SettingBoxKey.forceAdBlocker, forceAdBlocker);
                    setState(() {});
                  },
                  title: Text('广告过滤', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('强制启用HLS广告过滤，忽略规则设置', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: forceAdBlocker,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDisableAnimations = value ?? !playerDisableAnimations;
                    await setting.put(SettingBoxKey.playerDisableAnimations,
                        playerDisableAnimations);
                    setState(() {});
                  },
                  title: Text('禁用动画', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('禁用播放器内的过渡动画', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playerDisableAnimations,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    privateMode = value ?? !privateMode;
                    await setting.put(SettingBoxKey.privateMode, privateMode);
                    setState(() {});
                  },
                  title: Text('隐身模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('不保留观看记录', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: privateMode,
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showPlayerError = value ?? !showPlayerError;
                    await setting.put(
                        SettingBoxKey.showPlayerError, showPlayerError);
                    setState(() {});
                  },
                  title: Text('错误提示', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('显示播放器内部错误提示', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDebugMode = value ?? !playerDebugMode;
                    await setting.put(
                        SettingBoxKey.playerDebugMode, playerDebugMode);
                    setState(() {});
                  },
                  title: Text('调试模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('记录播放器内部日志', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playerDebugMode,
                ),
                SettingsTileSegmentedButton<int>(
                  title: Text('日志等级', style: TextStyle(fontFamily: fontFamily)),
                  segments: playerLogLevelMap.entries.map((entry) => ButtonSegment<int>(value: entry.key, label: Text(entry.value))).toList(),
                  selected: {playerLogLevel},
                  onSelectionChanged: (Set<int> newSelection) {
                    updatePlayerLogLevel(newSelection.first);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text('默认'),
              tiles: [
                SettingsTile(
                  title: Text('倍速', style: TextStyle(fontFamily: fontFamily)),
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
                SettingsTile.navigation(
                  description: Slider(
                    value: playerArrowKeySkipTime.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: '$playerArrowKeySkipTime秒',
                    onChanged: (value) {
                      final newArrowKeySkipTime = value.toInt();
                      print('新设置的方向键快进/快退时长: $newArrowKeySkipTime');

                      if (value != playerArrowKeySkipTime) {
                        setting.put(SettingBoxKey.arrowKeySkipTime,
                            newArrowKeySkipTime);
                        setState(() {
                          playerArrowKeySkipTime = newArrowKeySkipTime;
                        });
                      }
                    },
                  ),
                  title: Text('左右方向键的快进/快退秒数', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await updateButtonSkipTime();
                  },
                  title: Text('跳过时长', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('顶栏跳过按钮的秒数', style: TextStyle(fontFamily: fontFamily)),
                  value: Text('$playerButtonSkipTime 秒', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTileSegmentedButton<int>(
                  title: Text('视频比例', style: TextStyle(fontFamily: fontFamily)),
                  segments: aspectRatioTypeMap.entries.map((entry) => ButtonSegment<int>(value: entry.key, label: Text(entry.value))).toList(),
                  selected: {defaultAspectRatioType},
                  onSelectionChanged: (Set<int> newSelection) {
                    updateDefaultAspectRatioType(newSelection.first);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
