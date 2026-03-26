import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';

typedef TwoPaneChildBuilder = Widget Function(
  BuildContext context,
  double paneWidth,
  bool isTwoPane,
);

class TwoPaneDefaults {
  static final double minWidth = LayoutBreakpoint.medium['width']!;
  static const double leftPaneWidth = 400;
  static const Duration switchDuration = Duration(milliseconds: 480);
}

class TwoPaneLayout extends StatefulWidget {
  const TwoPaneLayout({
    super.key,
    required this.isTwoPane,
    required this.isInDetail,
    required this.foldableOptimization,
    required this.leftPaneBuilder,
    required this.rightPaneBuilder,
    this.onLeftPaneVisibilityChanged,
    this.leftPaneWidth = TwoPaneDefaults.leftPaneWidth,
    this.switchDuration = TwoPaneDefaults.switchDuration,
    this.switchCurve = Curves.easeOutCubic,
    this.clipBehavior = Clip.hardEdge,
  });

  final bool isTwoPane;
  final bool isInDetail;
  final bool foldableOptimization;
  final TwoPaneChildBuilder leftPaneBuilder;
  final TwoPaneChildBuilder rightPaneBuilder;
  final ValueChanged<bool>? onLeftPaneVisibilityChanged;
  final double leftPaneWidth;
  final Duration switchDuration;
  final Curve switchCurve;
  final Clip clipBehavior;

  static bool isLeftPaneVisible({
    required bool isTwoPane,
    required bool isInDetail,
  }) {
    return isTwoPane || !isInDetail;
  }

  @override
  State<TwoPaneLayout> createState() => _TwoPaneLayoutState();
}

class _TwoPaneLayoutState extends State<TwoPaneLayout> {
  bool _isNarrowFromWide = false;

  @override
  void didUpdateWidget(covariant TwoPaneLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTwoPane && !widget.isTwoPane) {
      _isNarrowFromWide = true;
      return;
    }
    if (widget.isTwoPane || !widget.isInDetail) {
      _isNarrowFromWide = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftPaneVisible = TwoPaneLayout.isLeftPaneVisible(
      isTwoPane: widget.isTwoPane,
      isInDetail: widget.isInDetail,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLeftPaneVisibilityChanged?.call(leftPaneVisible);
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftFixedWidth =
            widget.foldableOptimization ? totalWidth / 2 : widget.leftPaneWidth;
        late double leftX;
        late double leftWidth;
        late double rightX;
        late double rightWidth;

        if (widget.isTwoPane) {
          if (widget.isInDetail) {
            leftX = 0;
            leftWidth = leftFixedWidth;
            rightX = leftFixedWidth;
            rightWidth = (totalWidth - leftFixedWidth).clamp(0.0, totalWidth);
          } else {
            leftX = 0;
            leftWidth = totalWidth;
            rightX = totalWidth;
            rightWidth = totalWidth;
          }
        } else {
          final bool keepWideLeftWidth = _isNarrowFromWide && widget.isInDetail;
          leftWidth = keepWideLeftWidth ? widget.leftPaneWidth : totalWidth;
          rightWidth = totalWidth;
          leftX = widget.isInDetail ? -leftWidth : 0;
          rightX = widget.isInDetail ? 0 : totalWidth;
        }

        final canTapLeft = widget.isTwoPane ? true : !widget.isInDetail;
        final canTapRight = widget.isInDetail;

        return Stack(
          clipBehavior: widget.clipBehavior,
          children: [
            AnimatedPositioned(
              duration: widget.switchDuration,
              curve: widget.switchCurve,
              left: leftX,
              top: 0,
              bottom: 0,
              width: leftWidth,
              child: IgnorePointer(
                ignoring: !canTapLeft,
                child: widget.leftPaneBuilder(
                  context,
                  leftWidth,
                  widget.isTwoPane,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: widget.switchDuration,
              curve: widget.switchCurve,
              left: rightX,
              top: 0,
              bottom: 0,
              width: rightWidth,
              child: IgnorePointer(
                ignoring: !canTapRight,
                child: widget.rightPaneBuilder(
                  context,
                  rightWidth,
                  widget.isTwoPane,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
