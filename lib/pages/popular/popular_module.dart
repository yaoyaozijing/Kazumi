import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_module.dart';

class PopularModule extends Module {
  @override
  void routes(r) {
    r.child(
      "/",
      child: (_) => const PopularPage(),
      children: [
        ModuleRoute("/info", module: InfoModule(), transition: TransitionType.defaultTransition),
      ],
    );
  }
}
