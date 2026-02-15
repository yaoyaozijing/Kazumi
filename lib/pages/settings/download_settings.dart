import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  Box setting = GStorage.setting;
  late int parallelEpisodes;
  late int parallelSegments;
  late bool downloadDanmaku;

  @override
  void initState() {
    super.initState();
    parallelEpisodes = setting.get(
      SettingBoxKey.downloadParallelEpisodes,
      defaultValue: 2,
    );
    parallelSegments = setting.get(
      SettingBoxKey.downloadParallelSegments,
      defaultValue: 3,
    );
    downloadDanmaku = setting.get(
      SettingBoxKey.downloadDanmaku,
      defaultValue: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('下载设置')),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: Text('并发设置', style: TextStyle(fontFamily: fontFamily)),
            bottomInfo: Text(
              '• 较高的并发可提升速度，但可能被服务器限制\n'
              '• 修改后对新开始的下载生效'),
            tiles: [
              SettingsTile(
                title: Text('同时下载集数', style: TextStyle(fontFamily: fontFamily)),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同时下载 $parallelEpisodes 集',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    Slider(
                      value: parallelEpisodes.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$parallelEpisodes',
                      onChanged: (value) {
                        setState(() => parallelEpisodes = value.toInt());
                        setting.put(
                          SettingBoxKey.downloadParallelEpisodes,
                          parallelEpisodes,
                        );
                      },
                    ),
                  ],
                ),
              ),
              SettingsTile(
                title: Text('分片并发数', style: TextStyle(fontFamily: fontFamily)),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每集同时下载 $parallelSegments 个视频片段',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    Slider(
                      value: parallelSegments.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$parallelSegments',
                      onChanged: (value) {
                        setState(() => parallelSegments = value.toInt());
                        setting.put(
                          SettingBoxKey.downloadParallelSegments,
                          parallelSegments,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text('缓存设置', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => downloadDanmaku = value ?? !downloadDanmaku);
                  setting.put(SettingBoxKey.downloadDanmaku, downloadDanmaku);
                },
                title: Text('缓存弹幕', style: TextStyle(fontFamily: fontFamily)),
                description: Text(
                  '下载视频时同时缓存弹幕数据',
                  style: TextStyle(fontFamily: fontFamily),
                ),
                initialValue: downloadDanmaku,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
