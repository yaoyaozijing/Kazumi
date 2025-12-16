import 'package:flutter/material.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/constants.dart';

class SettingsTileSegmentedButton<T> extends AbstractSettingsTile {
  final Widget title;
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool? showSelectedIcon;

  SettingsTileSegmentedButton({
    super.key,
    required this.title,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.showSelectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = 1.3 * MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < LayoutBreakpoint.compact['width']!;
    final defaultShowSelectedIcon = showSelectedIcon ?? segments.length <= 3;
    return SettingsTile(
      title: title,
      trailing: isCompact ? null : SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiSelectionEnabled: multiSelectionEnabled,
      ),
      description: isCompact ? Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            segments: segments,
            selected: selected,
            onSelectionChanged: onSelectionChanged,
            multiSelectionEnabled: multiSelectionEnabled,
            showSelectedIcon: defaultShowSelectedIcon,
          ),
        ),
      ) : null,
    );
  }
}