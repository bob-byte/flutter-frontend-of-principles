import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../models/task_subtask.dart';
import '../viewmodels/edit_task_viewmodel.dart';
import 'completion_check.dart';

class TaskSubtasksEditor extends StatefulWidget {
  const TaskSubtasksEditor({
    super.key,
    required this.vm,
    required this.palette,
    required this.strings,
  });

  final EditTaskViewModel vm;
  final TasksUiPalette palette;
  final TaskStrings strings;

  @override
  State<TaskSubtasksEditor> createState() => _TaskSubtasksEditorState();
}

class _TaskSubtasksEditorState extends State<TaskSubtasksEditor> {
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  Set<String> _knownIds = {};
  String? _autofocusId;

  static const _borderless = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  void initState() {
    super.initState();
    _knownIds = {for (final item in widget.vm.subtasks) item.id};
    _syncControllers(widget.vm.subtasks);
  }

  @override
  void didUpdateWidget(covariant TaskSubtasksEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers(widget.vm.subtasks);
    for (final item in widget.vm.subtasks) {
      if (_knownIds.contains(item.id) || item.title.isNotEmpty) continue;
      _autofocusId = item.id;
      _queueKeyboardFocus(item.id);
    }
    _knownIds = {for (final item in widget.vm.subtasks) item.id};
  }

  void _syncControllers(List<TaskSubtask> subtasks) {
    final ids = {for (final item in subtasks) item.id};
    for (final id in _controllers.keys.toList()) {
      if (ids.contains(id)) continue;
      _controllers.remove(id)?.dispose();
      _focusNodes.remove(id)?.dispose();
    }
    for (final item in subtasks) {
      final existing = _controllers[item.id];
      if (existing == null) {
        _controllers[item.id] = TextEditingController(text: item.title);
        _focusNodes[item.id] = FocusNode();
        continue;
      }
      final node = _focusNodes[item.id];
      if (node != null && !node.hasFocus && existing.text != item.title) {
        existing.text = item.title;
      }
    }
  }

  void _queueKeyboardFocus(String id) {
    void focus() {
      if (!mounted) return;
      final node = _focusNodes[id];
      if (node == null || !node.canRequestFocus) return;
      node.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }

    // Run before and after the frame so iOS never sees a focus gap long
    // enough to animate the keyboard away.
    focus();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus());
  }

  void _onAddSubtask() {
    if (widget.vm.isSaving) return;
    // Show IME immediately in case focus briefly drops on the tap itself.
    SystemChannels.textInput.invokeMethod('TextInput.show');
    widget.vm.addSubtask();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final palette = widget.palette;
    final strings = widget.strings;
    final items = vm.subtasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          _SubtaskRow(
            key: ValueKey(items[i].id),
            item: items[i],
            isLast: i == items.length - 1,
            autofocus: items[i].id == _autofocusId,
            controller: _controllers[items[i].id]!,
            focusNode: _focusNodes[items[i].id]!,
            palette: palette,
            strings: strings,
            decoration: _borderless,
            onToggle: () => vm.toggleSubtaskDone(items[i].id),
            onTitleChanged: (value) => vm.setSubtaskTitle(items[i].id, value),
            onSubmitted: () {
              if (i == items.length - 1 &&
                  _controllers[items[i].id]!.text.trim().isNotEmpty) {
                _onAddSubtask();
              }
            },
            onRemove: () => vm.removeSubtask(items[i].id),
          ),
        Align(
          alignment: Alignment.centerLeft,
          // No Material/Focus widget: TextButton steals focus and hides IME.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: vm.isSaving ? null : _onAddSubtask,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: palette.primary),
                  const SizedBox(width: 4),
                  Text(
                    strings.taskAddSubtask,
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    super.key,
    required this.item,
    required this.isLast,
    required this.autofocus,
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.strings,
    required this.decoration,
    required this.onToggle,
    required this.onTitleChanged,
    required this.onSubmitted,
    required this.onRemove,
  });

  final TaskSubtask item;
  final bool isLast;
  final bool autofocus;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TasksUiPalette palette;
  final TaskStrings strings;
  final InputDecoration decoration;
  final VoidCallback onToggle;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
            child: CompletionCheckButton(
              isDone: item.isDone,
              palette: palette,
              size: 20,
              iconSize: 13,
              showShadow: false,
              burstRadius: 34,
              onToggle: onToggle,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onTapOutside: (_) {},
              textCapitalization: TextCapitalization.sentences,
              textInputAction: isLast
                  ? TextInputAction.done
                  : TextInputAction.next,
              style: TextStyle(
                fontSize: 15,
                color: item.isDone ? palette.textMuted : palette.textPrimary,
                decoration: item.isDone ? TextDecoration.lineThrough : null,
                height: 1.35,
              ),
              decoration: decoration.copyWith(
                hintText: strings.taskSubtaskHint,
                hintStyle: TextStyle(
                  color: palette.textMuted.withValues(alpha: 0.65),
                  fontSize: 15,
                ),
              ),
              onChanged: onTitleChanged,
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: palette.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
