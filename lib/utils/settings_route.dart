import 'package:flutter_modular/flutter_modular.dart';

String resolveSettingsRoute(String route) {
  if (!route.startsWith('/settings')) {
    return route;
  }
  if (Modular.to.path.startsWith('/tab/my/settings')) {
    return '/tab/my$route';
  }
  return route;
}

Future<T?> pushSettingsRoute<T extends Object?>(
  String route, {
  Object? arguments,
  bool forRoot = false,
}) {
  return Modular.to.pushNamed<T>(
    resolveSettingsRoute(route),
    arguments: arguments,
    forRoot: forRoot,
  );
}
