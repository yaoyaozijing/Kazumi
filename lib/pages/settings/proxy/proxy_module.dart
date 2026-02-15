import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProxyModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child(
      "/",
      child: (_) => const ProxySettingsPage(),
      transition: TransitionType.defaultTransition,
    );
  }
}
