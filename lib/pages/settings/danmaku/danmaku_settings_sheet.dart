import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DanmakuSettingsSheet extends StatefulWidget {
  final DanmakuController danmakuController;

  const DanmakuSettingsSheet({super.key, required this.danmakuController});

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  Box setting = GStorage.setting;

  void showDanmakuShieldSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (Utils.isDesktop() || Utils.isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return DanmakuShieldSettings();
        });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsList(
      sections: [
        SettingsSection(
          title: const Text('弹幕屏蔽'),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                showDanmakuShieldSheet();
              },
              title: const Text('关键词屏蔽'),
            ),
          ],
        ),
        SettingsSection(
          title: const Text('弹幕样式'),
          tiles: [
            SettingsTile(
              title: const Text('字体大小'),
              description: Slider(
                value: widget.danmakuController.option.fontSize,
                min: 10,
                max: Utils.isCompact() ? 32 : 48,
                label:
                    '${widget.danmakuController.option.fontSize.floorToDouble()}',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          fontSize: value.floorToDouble(),
                        ),
                      ));
                  setting.put(
                      SettingBoxKey.danmakuFontSize, value.floorToDouble());
                },
              ),
            ),
            SettingsTile(
              title: const Text('弹幕不透明度'),
              description: Slider(
                value: widget.danmakuController.option.opacity,
                min: 0.1,
                max: 1,
                label:
                    '${(widget.danmakuController.option.opacity * 100).round()}%',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          opacity: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuOpacity,
                      double.parse(value.toStringAsFixed(2)));
                },
              ),
            ),
          ],
        ),
        SettingsSection(
          title: const Text('弹幕显示'),
          tiles: [
            SettingsTile(
              title: const Text('屏幕占比'),
              description: Slider(
                value: widget.danmakuController.option.area,
                min: 0.25,
                max: 1.0,
                divisions: 3,
                label:
                    '${(widget.danmakuController.option.area * 4).round()}/4',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          area: value,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuArea, value);
                },
              ),
            ),
            SettingsTile.navigation(
              title: const Text('弹幕类型'),
              value: SegmentedButton<String>(
                multiSelectionEnabled: true,
                segments: const [
                  ButtonSegment<String>(value: 'top', label: Text('顶部')),
                  ButtonSegment<String>(value: 'bottom', label: Text('底部')),
                  ButtonSegment<String>(value: 'scroll', label: Text('滚动')),
                ],
                selected: {
                  if (!widget.danmakuController.option.hideTop) 'top',
                  if (!widget.danmakuController.option.hideBottom) 'bottom',
                  if (!widget.danmakuController.option.hideScroll) 'scroll',
                },
                onSelectionChanged: (Set<String> selected) async {
                  setState(() {
                    widget.danmakuController.updateOption(
                      widget.danmakuController.option.copyWith(
                        hideTop: !selected.contains('top'),
                        hideBottom: !selected.contains('bottom'),
                        hideScroll: !selected.contains('scroll'),
                      ),
                    );
                  });
                  setting.put(SettingBoxKey.danmakuTop, selected.contains('top'));
                  setting.put(SettingBoxKey.danmakuBottom, selected.contains('bottom'));
                  setting.put(SettingBoxKey.danmakuScroll, selected.contains('scroll'));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
