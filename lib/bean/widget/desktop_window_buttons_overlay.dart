import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowButtonsOverlay extends StatelessWidget {
  const DesktopWindowButtonsOverlay({
    super.key,
    required this.child,
  });

  static final ValueNotifier<bool> isInPlayer = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isPlayerPanelVisible =
      ValueNotifier<bool>(true);

  static void setInPlayer(bool value) {
    _setNotifierValue(isInPlayer, value);
  }

  static void setPlayerPanelVisible(bool value) {
    _setNotifierValue(isPlayerPanelVisible, value);
  }

  static void _setNotifierValue(ValueNotifier<bool> notifier, bool value) {
    if (notifier.value == value) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    final isBuildingPhase = phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    if (isBuildingPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (notifier.value != value) {
          notifier.value = value;
        }
      });
      return;
    }
    notifier.value = value;
  }

  final Widget child;

  bool _shouldShowOverlay() {
    if (!Utils.isDesktop()) {
      return false;
    }
    final showSystemWindowButtons = GStorage.setting.get(
          SettingBoxKey.showWindowButton,
          defaultValue: false,
        ) ==
        true;
    return !showSystemWindowButtons;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowOverlay()) {
      return child;
    }
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (context) => child),
        OverlayEntry(
          builder: (context) => Positioned(
            top: -4,
            right: 4,
            child: ValueListenableBuilder<bool>(
              valueListenable: isInPlayer,
              builder: (context, inPlayer, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: isPlayerPanelVisible,
                  builder: (context, panelVisible, __) {
                    return _AutoHideWindowButtonsArea(
                      autoHideEnabled: inPlayer && !panelVisible,
                      forceWhite: inPlayer,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoHideWindowButtonsArea extends StatefulWidget {
  const _AutoHideWindowButtonsArea({
    required this.autoHideEnabled,
    required this.forceWhite,
  });

  final bool autoHideEnabled;
  final bool forceWhite;

  @override
  State<_AutoHideWindowButtonsArea> createState() =>
      _AutoHideWindowButtonsAreaState();
}

class _AutoHideWindowButtonsAreaState
    extends State<_AutoHideWindowButtonsArea> {
  static const Duration _visibilityAnimationDuration =
      Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final hideButtons = widget.autoHideEnabled;
    return IgnorePointer(
      ignoring: hideButtons,
      child: AnimatedSlide(
        duration: _visibilityAnimationDuration,
        curve: Curves.easeInOut,
        offset: hideButtons ? const Offset(0, -1) : Offset.zero,
        child: AnimatedOpacity(
          duration: _visibilityAnimationDuration,
          curve: Curves.easeInOut,
          opacity: hideButtons ? 0 : 1,
          child: _WindowButtonsBar(forceWhite: widget.forceWhite),
        ),
      ),
    );
  }
}

class _WindowButtonsBar extends StatelessWidget {
  const _WindowButtonsBar({
    required this.forceWhite,
  });

  final bool forceWhite;

  IconButton _buildWindowButton({
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 58, height: 58),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = forceWhite
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black);
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWindowButton(
            tooltip: '最小化',
            onPressed: () => windowManager.minimize(),
            icon: Icons.remove,
            color: buttonColor,
          ),
          const SizedBox(width: 8),
          _buildWindowButton(
            tooltip: '最大化/还原',
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            icon: Icons.crop_square,
            color: buttonColor,
          ),
          const SizedBox(width: 8),
          _buildWindowButton(
            tooltip: '关闭',
            onPressed: () => windowManager.close(),
            icon: Icons.close,
            color: buttonColor,
          ),
        ],
      ),
    );
  }
}
