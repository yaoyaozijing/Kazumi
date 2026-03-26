import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:window_manager/window_manager.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  static final ValueNotifier<int> _compactMyBackSignal = ValueNotifier<int>(0);
  static void notifyLeadingRefresh() => _compactMyBackSignal.value++;

  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;

  final ShapeBorder? shape;

  final List<Widget>? actions;

  final Widget? leading;

  final double? leadingWidth;

  final PreferredSizeWidget? bottom;

  final bool needTopOffset;
  final bool showDesktopCloseButton;

  const SysAppBar(
      {super.key,
      this.toolbarHeight,
      this.title,
      this.backgroundColor,
      this.elevation,
      this.shape,
      this.actions,
      this.leading,
      this.leadingWidth,
      this.bottom,
      this.needTopOffset = true,
      this.showDesktopCloseButton = true});

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  double _desktopRightInset() {
    if (!Utils.isDesktop()) {
      return 0;
    }
    // Follow the legacy close-button visibility rule:
    // when the desktop close button is hidden (usually left pane), no extra right inset.
    if (!showWindowButton() && showDesktopCloseButton) {
      return 168;
    }
    return 8;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (Utils.isDesktop()) {
      acs.add(SizedBox(width: _desktopRightInset()));
    }
    return GestureDetector(
      onPanStart: (_) =>
          (Utils.isDesktop()) ? windowManager.startDragging() : null,
      child: ValueListenableBuilder<int>(
        valueListenable: _compactMyBackSignal,
        builder: (context, _, __) {
          final autoLeading = _buildAutoLeading(context);
          return AppBar(
            toolbarHeight: preferredSize.height,
            scrolledUnderElevation: 0.0,
            title: title != null
                ? EmbeddedNativeControlArea(
                    requireOffset: needTopOffset,
                    child: title!,
                  )
                : null,
            centerTitle: Platform.isIOS ? true : false,
            actions: acs.map((e) {
              return EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: e,
              );
            }).toList(),
            leading: leading != null
                ? EmbeddedNativeControlArea(
                    requireOffset: needTopOffset,
                    child: leading!,
                  )
                : autoLeading,
            leadingWidth: leadingWidth,
            backgroundColor: backgroundColor,
            elevation: elevation,
            shape: shape,
            bottom: bottom,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  Theme.of(context).brightness == Brightness.light
                      ? Brightness.dark
                      : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize {
    // macOS needs to add 22(macOS title bar height)
    // to default toolbar height to build appbar like normal
    if (Platform.isMacOS && needTopOffset && showWindowButton()) {
      if (toolbarHeight != null) {
        return Size.fromHeight(toolbarHeight! + 22);
      } else {
        return const Size.fromHeight(kToolbarHeight + 22);
      }
    } else {
      return Size.fromHeight(toolbarHeight ?? kToolbarHeight);
    }
  }

  Widget? _buildAutoLeading(BuildContext context) {
    const mySettingsPrefix = '/tab/my/settings';
    final canPopNavigator = Navigator.canPop(context);
    final canPopModular = Modular.to.canPop();
    final path = Modular.to.path;
    final isMySettings = path.startsWith(mySettingsPrefix);
    final isMySettingsCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoint.medium['width']! &&
            isMySettings;
    final shouldShowBackButton =
        canPopNavigator || canPopModular || isMySettingsCompact;

    if (!shouldShowBackButton) {
      return null;
    }

    return EmbeddedNativeControlArea(
      requireOffset: needTopOffset,
      child: IconButton(
        onPressed: () {
          final segments = isMySettings
              ? path
                  .substring(mySettingsPrefix.length)
                  .split('/')
                  .where((s) => s.isNotEmpty)
                  .toList()
              : const <String>[];

          if (isMySettingsCompact) {
            if (segments.length <= 1) {
              Modular.to.navigate('/tab/my/');
              return;
            }
            final parent = segments.take(segments.length - 1).join('/');
            Modular.to.navigate('/tab/my/settings/$parent');
            return;
          }
          if (canPopNavigator) {
            Navigator.maybePop(context);
            return;
          }
          if (canPopModular) {
            Modular.to.pop();
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}
