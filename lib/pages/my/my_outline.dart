import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/my/my_state.dart';
import 'package:kazumi/pages/my/my_outline_items.dart';

class MyOutline extends StatelessWidget {
  const MyOutline({super.key, this.onSelect});

  final ValueChanged<String>? onSelect;

  void _handleTap(BuildContext context, String route) {
    if (onSelect != null) {
      onSelect!(route);
    } else {
      Provider.of<MyState>(context, listen: false).open(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return SettingsList(
      maxWidth: 1000,
      sections: myOutlineSections.map((section) {
        return SettingsSection(
          title: section.title != null
              ? Text(section.title!, style: TextStyle(fontFamily: fontFamily))
              : const SizedBox.shrink(),
          tiles: section.tiles.map((tile) {
            // 特殊处理 logo
            if (tile.title == '关于') {
              return SettingsTile.navigation(
                onPressed: (_) => _handleTap(context, tile.route),
                title: Center(
                  child: Image.asset(
                    'assets/images/mypage_logo.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }

            return SettingsTile.navigation(
              onPressed: (_) => _handleTap(context, tile.route),
              leading: tile.icon != null ? Icon(tile.icon) : null,
              title: Text(tile.title, style: TextStyle(fontFamily: fontFamily)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
