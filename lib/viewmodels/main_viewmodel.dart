import 'package:flutter/material.dart';

class MainViewModel extends ChangeNotifier {
  // Start on Progress View (Dashboard)
  int _currentIndex = 1; 

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
