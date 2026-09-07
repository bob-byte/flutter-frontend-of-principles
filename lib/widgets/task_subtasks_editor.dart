import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../models/task_subtask.dart';
import '../viewmodels/edit_task_viewmodel.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNodes[item.id]?.requestFocus();
      });
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
        Text(
          strings.taskSubtasksLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          _SubtaskRow(
            key: ValueKey(items[i].id),
            item: items[i],
            isLast: i == items.length - 1,
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
                vm.addSubtask();
              }
            },
            onRemove: () => vm.removeSubtask(items[i].id),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: vm.isSaving ? null : vm.addSubtask,
            style: TextButton.styleFrom(
              foregroundColor: palette.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(strings.taskAddSubtask),
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
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
              child: _SubtaskCheckbox(palette: palette, isDone: item.isDone),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
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
          IconButton(
            tooltip: strings.taskRemoveSubtask,
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: palette.textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskCheckbox extends StatelessWidget {
  const _SubtaskCheckbox({required this.palette, required this.isDone});

  final TasksUiPalette palette;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDone ? palette.primaryGradient : null,
        color: isDone ? null : palette.glassChipFill,
        border: isDone
            ? null
            : Border.all(color: palette.glassBorder, width: 1.4),
      ),
      child: isDone
          ? Icon(Icons.check_rounded, size: 13, color: palette.onPrimary)
          : null,
    );
  }
}
