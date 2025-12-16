import 'package:flutter/material.dart';

class ThemePreviewCard extends StatelessWidget {
  final Color? primary;
  final bool dynamic;
  final bool selected;

  const ThemePreviewCard({
    super.key,
    this.primary,
    this.dynamic = false,
    required this.selected,
  });

  ColorScheme _resolveScheme(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    if (dynamic) return base;
    return ColorScheme.fromSeed(
      seedColor: primary!,
      brightness: base.brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _resolveScheme(context);
    final outline = selected ? scheme.primary : scheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 96,
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: outline,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 上半部分：封面 + 标题文字
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          color: scheme.onSurfaceVariant.withAlpha(128),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 8,
                          width: double.infinity,
                          color: scheme.onSurfaceVariant.withAlpha(96),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      color: scheme.onSurfaceVariant.withAlpha(72),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      width: double.infinity,
                      color: scheme.onSurfaceVariant.withAlpha(72),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      width: 60,
                      color: scheme.onSurfaceVariant.withAlpha(72),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 12,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(48),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
