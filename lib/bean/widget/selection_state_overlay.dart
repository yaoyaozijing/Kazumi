import 'package:flutter/material.dart';

class SelectionStateOverlay extends StatelessWidget {
  const SelectionStateOverlay({
    super.key,
    required this.isSelectionMode,
    required this.isSelected,
    required this.borderRadius,
  });

  final bool isSelectionMode;
  final bool isSelected;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isSelectionMode) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
