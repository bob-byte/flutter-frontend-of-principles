import 'package:flutter/material.dart';

class LocaleController extends ChangeNotifier {
  Locale? _localeOverride;

  Locale? get localeOverride => _localeOverride;

  void setLocaleOverride(Locale? locale) {
    _localeOverride = locale;
    notifyListeners();
  }
}
