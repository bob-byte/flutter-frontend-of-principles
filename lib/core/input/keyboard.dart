import 'package:flutter/widgets.dart';

/// Dismisses the soft keyboard and clears text focus.
///
/// Flutter counterpart of MAUI [KeyboardHelper.HideKeyboard]. Call before
/// showing UI that does not need typing (date/time pickers, menus, sheets).
void hideSoftKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}
