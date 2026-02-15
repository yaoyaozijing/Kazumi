import 'package:kazumi/pages/my/my_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/settings/settings_module.dart';

class MyModule extends Module {
  @override
  void routes(r) {
    r.child(
      "/",
      child: (_) => const MyPage(),
      children: [
        ModuleRoute("/settings", module: SettingsModule()),
      ],
    );
  }
}
