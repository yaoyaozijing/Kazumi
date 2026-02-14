import 'package:flutter/material.dart';

class MyState extends ChangeNotifier {
  String? _currentRoute;

  String? get currentRoute => _currentRoute;
  bool get hasDetail => _currentRoute != null;

  void open(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  void clear() {
    _currentRoute = null;
    notifyListeners();
  }
}
