import 'dart:io';
import 'package:flutter/material.dart';
import 'theme_preview_card.dart';

class ColorSchemeSelector extends StatelessWidget {
  final List<Map<String, dynamic>> colorThemes;
  final String defaultThemeColor;
  final bool useDynamicColor;
  final VoidCallback resetTheme;
  final void Function(Color color) setTheme;
  final void Function(bool value) setDynamic;
  final VoidCallback onChanged;

  const ColorSchemeSelector({
    super.key,
    required this.colorThemes,
    required this.defaultThemeColor,
    required this.useDynamicColor,
    required this.resetTheme,
    required this.setTheme,
    required this.setDynamic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasDynamicItem = !Platform.isIOS;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: colorThemes.length + (hasDynamicItem ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        if (hasDynamicItem && index == 0) {
          final selected = useDynamicColor;

          return _Item(
            label: '动态配色',
            selected: selected,
            onTap: () {
              setDynamic(true);
              onChanged();
            },
            child: ThemePreviewCard(
              dynamic: true,
              selected: selected, // 外部控制颜色
            ),
          );
        }

        final realIndex = hasDynamicItem ? index - 1 : index;
        final e = colorThemes[realIndex];
        final color = e['color'] as Color;
        final label = e['label'] as String;

        final selected =
            !useDynamicColor &&
            ((defaultThemeColor == 'default' && realIndex == 0) ||
                color.value.toRadixString(16) == defaultThemeColor);

        return _Item(
          label: label,
          selected: selected,
          onTap: () {
            setDynamic(false);
            realIndex == 0 ? resetTheme() : setTheme(color);
            onChanged();
          },
          child: ThemePreviewCard(
            primary: color,
            selected: selected,
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  final Widget child;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Item({
    required this.child,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
