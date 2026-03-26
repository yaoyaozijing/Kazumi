import 'package:kazumi/pages/collect/collect_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_module.dart';

class CollectModule extends Module {
  @override
  void routes(r) {
    r.child(
      "/",
      child: (_) => const CollectPage(),
      children: [
        ModuleRoute('/info', module: InfoModule(), transition: TransitionType.defaultTransition),
      ],
    );
  }
}
