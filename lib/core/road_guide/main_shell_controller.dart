import 'package:flutter/material.dart';

/// Tab indices in [MainShell]'s IndexedStack / GlassTabBar.
abstract final class MainShellTab {
  static const chat = 0;
  static const goals = 1;
  static const tasks = 2;
  static const habits = 3;
  static const settings = 4;
}

/// Owns the post-login shell tab index so the road guide can switch tabs.
class MainShellController extends ChangeNotifier {
  int _index = MainShellTab.tasks;

  int get index => _index;

  void setIndex(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
