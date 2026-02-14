import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/my/my_outline.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_state.dart';
import 'package:kazumi/pages/my/my_outline_items.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late NavigationBarState navigationBarState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }

    final myState = Provider.of<MyState>(context, listen: false);

    // 窄屏 detail -> 返回 outline
    if (myState.hasDetail &&
        MediaQuery.of(context).size.width < 900) {
      myState.clear();
      return;
    }

    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackPressed(context);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Consumer<MyState>(
              builder: (context, state, _) {
                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: MyOutline(
                          onSelect: state.open, // ✅ 修复 select 错误
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      const Expanded(
                        child: _MyDetailPane(),
                      ),
                    ],
                  );
                }

                if (state.hasDetail) {
                  return const _MyDetailPane();
                }

                return const MyOutline();
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyDetailPane extends StatelessWidget {
  const _MyDetailPane();

  @override
  Widget build(BuildContext context) {
    final route = Provider.of<MyState>(context).currentRoute;

    // route 为 null，显示提示
    if (route == null) {
      return const Center(
        child: Text(
          '请选择左侧的设置项',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // ⚡ 使用局部变量，避免 public 字段无法提升的问题
    final currentRoute = route;

    // 查找匹配的 tile
    final item = myOutlineSections
        .expand((s) => s.tiles)
        .firstWhere(
          (t) => currentRoute.startsWith(t.route),
          orElse: () => OutlineTile(
            title: '未知设置',
            route: '',
            pageBuilder: () => const SizedBox.shrink(), // 可以为 null
          ),
        );

    // ⚡ 安全调用 pageBuilder
    return item.pageBuilder?.call() ??
        Center(
          child: Text(
            '未实现的设置页面：\n$currentRoute',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        );
  }
}
