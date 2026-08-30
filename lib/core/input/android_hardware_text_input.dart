import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// On Android emulators the host keyboard is a hardware keyboard, but Flutter
/// text fields wait for IME commits that never arrive. This inserts those keys.
class AndroidHardwareTextInput extends StatefulWidget {
  const AndroidHardwareTextInput({super.key, required this.child});

  final Widget child;

  @override
  State<AndroidHardwareTextInput> createState() =>
      _AndroidHardwareTextInputState();
}

class _AndroidHardwareTextInputState extends State<AndroidHardwareTextInput> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_hasModifier()) return false;

    final editable = _focusedEditable();
    if (editable == null || editable.widget.readOnly) return false;

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      return _delete(editable);
    }

    final character = event.character;
    if (character == null || character.isEmpty) return false;
    if (character == '\n' || character == '\r') return false;

    return _insert(editable, character);
  }

  bool _hasModifier() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight);
  }

  EditableTextState? _focusedEditable() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    return context.findAncestorStateOfType<EditableTextState>();
  }

  bool _insert(EditableTextState editable, String character) {
    final value = editable.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid) return false;

    final start = selection.start;
    final newText = value.text.replaceRange(start, selection.end, character);
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + character.length),
        composing: TextRange.empty,
      ),
      SelectionChangedCause.keyboard,
    );
    return true;
  }

  bool _delete(EditableTextState editable) {
    final value = editable.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid) return false;

    var start = selection.start;
    final end = selection.end;
    if (selection.isCollapsed) {
      if (start == 0) return true;
      start = value.text.substring(0, start).characters.skipLast(1).string.length;
    }

    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: value.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      ),
      SelectionChangedCause.keyboard,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
