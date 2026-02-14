import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';

import 'package:kazumi/pages/my/my_page.dart';
import 'package:kazumi/pages/my/my_state.dart';

class MyModule extends Module {
  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => ChangeNotifierProvider<MyState>(
        create: (_) => MyState(),
        child: const MyPage(),
      ),
    );
  }
}
