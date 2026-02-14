import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/my/my_state.dart';
import 'package:kazumi/pages/my/my_outline_items.dart';
import '../../bean/appbar/sys_app_bar.dart';

class SettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final List<Widget>? actions;

  const SettingsAppBar({
    super.key,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final myState = context.watch<MyState>();
    final route = myState.currentRoute;

    return SysAppBar(
      title: _BreadcrumbTitle(
        route: route,
        onRootTap: () {
          myState.clear();
        },
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _BreadcrumbTitle extends StatelessWidget {
  final String? route;
  final VoidCallback onRootTap;

  const _BreadcrumbTitle({
    required this.route,
    required this.onRootTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 一级标题
    final root = GestureDetector(
      onTap: route != null ? onRootTap : null,
      child: Text(
        '设置',
        style: theme.textTheme.titleLarge,
      ),
    );

    if (route == null) return root;

    // 二级标题，从数据文件查找
    final leafItem = myOutlineSections
        .expand((s) => s.tiles)
        .firstWhere(
          (t) => route?.startsWith(t.route) ?? false,
          orElse: () => OutlineTile(
            title: '未知',
            route: '',
            pageBuilder: () => const SizedBox.shrink(),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        root,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right, size: 18),
        ),
        Text(
          leafItem.title,
          style: theme.textTheme.titleLarge,
        ),
      ],
    );
  }
}
