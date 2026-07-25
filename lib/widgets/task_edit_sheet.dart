import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/utils/date_helpers.dart';
import '../l10n/task_strings.dart';
import '../models/ai_task_draft.dart';
import '../models/task_priority.dart';
import '../viewmodels/edit_task_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'theme_picker_section.dart';
import 'tasks_glass.dart';

Future<bool?> showTaskEditSheet(
  BuildContext context, {
  String? taskId,
  AiTaskDraft? draft,
}) async {
  final tasksVm = context.read<TasksViewModel>();
  final editVm = context.read<EditTaskViewModel>();

  await editVm.load(taskId: taskId, draft: draft);
  if (!context.mounted) return null;

  // Для нового завдання без дати від AI — підставити дату з режиму списку.
  if (taskId == null && (draft == null || !draft.hasDueDate)) {
    switch (tasksVm.listMode) {
      case TasksListMode.inbox:
        editVm.setHasDueDate(false);
      case TasksListMode.day:
        editVm.setHasDueDate(true);
        editVm.setDueDate(tasksVm.selectedDay);
      case TasksListMode.today:
        editVm.setHasDueDate(true);
        editVm.setDueDate(dateOnly(DateTime.now()));
    }
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Theme(
      data: tasksVm.themeData,
      child: TaskEditSheet(taskId: taskId),
    ),
  );
}

class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({super.key, this.taskId});

  final String? taskId;

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocus = FocusNode();
  bool _optionsExpanded = false;
  bool _titleError = false;

  static const _borderlessDecoration = InputDecoration(
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<EditTaskViewModel>();
      _syncControllers(vm);
      if (widget.taskId == null) _titleFocus.requestFocus();
    });
  }

  void _syncControllers(EditTaskViewModel vm) {
    _titleController.text = vm.title;
    _descriptionController.text = vm.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate(EditTaskViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      vm.setHasDueDate(true);
      vm.setDueDate(picked);
    }
  }

  Future<void> _save(EditTaskViewModel vm) async {
    if (vm.title.trim().isEmpty) {
      setState(() => _titleError = true);
      _titleFocus.requestFocus();
      return;
    }
    final ok = await vm.save();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _onTitleChanged(EditTaskViewModel vm, String value) {
    vm.setTitle(value);
    if (_titleError && value.trim().isNotEmpty) {
      setState(() => _titleError = false);
    }
  }

  Future<void> _delete(TaskStrings strings) async {
    final taskId = widget.taskId;
    if (taskId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.taskDelete),
        content: Text(strings.taskDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.taskCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.taskDelete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<TasksViewModel>().deleteTask(taskId);
    if (mounted) Navigator.of(context).pop(true);
  }

  String _dateLabel(TaskStrings strings, EditTaskViewModel vm) {
    if (!vm.hasDueDate) return strings.taskNoDueDate;
    final due = vm.dueDate;
    if (due == null) return strings.taskPickDate;
    if (isSameDay(due, dateOnly(DateTime.now()))) return strings.taskMenuToday;
    return formatTaskDate(due);
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    final palette = context.watch<TasksViewModel>().palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Consumer<EditTaskViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _SheetSurface(
              palette: palette,
              child: const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _SheetSurface(
            palette: palette,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          focusNode: _titleFocus,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary,
                            height: 1.35,
                          ),
                          decoration: _borderlessDecoration.copyWith(
                            hintText: strings.taskWhatNeedsToBeDone,
                            hintStyle: TextStyle(
                              color: palette.textMuted.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w400,
                              fontSize: 17,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (value) => _onTitleChanged(vm, value),
                        ),
                        if (_titleError) ...[
                          const SizedBox(height: 6),
                          Text(
                            strings.taskNameRequired,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: palette.textMuted.withValues(alpha: 0.22),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _descriptionController,
                          minLines: 1,
                          maxLines: 6,
                          style: TextStyle(
                            fontSize: 15,
                            color: palette.textPrimary,
                            height: 1.4,
                          ),
                          decoration: _borderlessDecoration.copyWith(
                            hintText: strings.taskDescriptionHint,
                            hintStyle: TextStyle(
                              color: palette.textMuted.withValues(alpha: 0.65),
                              fontSize: 15,
                            ),
                          ),
                          onChanged: vm.setDescription,
                        ),
                        if (_optionsExpanded) ...[
                          const SizedBox(height: 24),
                          ThemePickerSection(
                            mode: vm.themeMode,
                            colorForTheme: vm.colorForTheme,
                            existingThemes: vm.sortedThemes,
                            selectedTheme: vm.selectedTheme,
                            selectedColor: vm.themeColor,
                            newThemeName: vm.newThemeName,
                            onModeChanged: vm.setThemeMode,
                            onThemeSelected: vm.setSelectedTheme,
                            onNewThemeNameChanged: vm.setNewThemeName,
                            onColorSelected: vm.setThemeColor,
                            strings: strings,
                          ),
                        ],
                        if (widget.taskId != null) ...[
                          const SizedBox(height: 28),
                          Center(
                            child: TextButton.icon(
                              onPressed: vm.isSaving
                                  ? null
                                  : () => _delete(strings),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              label: Text(
                                strings.taskDelete,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: palette.cardBorder.withValues(alpha: 0.35),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ActionChip(
                              palette: palette,
                              icon: Icons.calendar_today_outlined,
                              label: _dateLabel(strings, vm),
                              active: vm.hasDueDate,
                              onTap: () async {
                                if (vm.hasDueDate) {
                                  await _pickDate(vm);
                                } else {
                                  vm.setHasDueDate(true);
                                  vm.setDueDate(dateOnly(DateTime.now()));
                                }
                              },
                              onLongPress: () {
                                vm.setHasDueDate(!vm.hasDueDate);
                              },
                            ),
                            _PriorityChip(
                              palette: palette,
                              priority: vm.priority,
                              strings: strings,
                              onSelected: vm.setPriority,
                            ),
                            _ActionChip(
                              palette: palette,
                              icon: Icons.label_outline,
                              label: vm.resolvedTheme() ?? strings.taskNoTheme,
                              active: vm.themeMode != ThemePickerMode.none,
                              onTap: () => setState(
                                () => _optionsExpanded = !_optionsExpanded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SubmitButton(
                        palette: palette,
                        isSaving: vm.isSaving,
                        onPressed: vm.isSaving ? null : () => _save(vm),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.palette, required this.child});

  final TasksUiPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TasksGlassSheet(
      palette: palette,
      child: child,
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent = active ? palette.primary : palette.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? palette.textPrimary : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.palette,
    required this.priority,
    required this.strings,
    required this.onSelected,
  });

  final TasksUiPalette palette;
  final TaskPriority? priority;
  final TaskStrings strings;
  final ValueChanged<TaskPriority?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPriority = priority != null;
    final color =
        hasPriority ? priorityColor(priority!, scheme) : palette.textMuted;
    final label =
        hasPriority ? priority!.label(strings) : strings.taskPriorityNone;

    return PopupMenuButton<TaskPriority?>(
      initialValue: priority,
      onSelected: onSelected,
      offset: const Offset(0, -168),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.remove_circle_outline, size: 16, color: palette.textMuted),
              const SizedBox(width: 10),
              Text(strings.taskPriorityNone),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...TaskPriority.values.map(
          (p) => PopupMenuItem(
            value: p,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor(p, scheme),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(p.label(strings)),
              ],
            ),
          ),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, size: 18, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasPriority ? color : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.palette,
    required this.isSaving,
    required this.onPressed,
  });

  final TasksUiPalette palette;
  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(24),
      blur: 14,
      tint: palette.primary.withValues(alpha: palette.isDark ? 0.88 : 0.92),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: isSaving
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.onPrimary,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    color: palette.onPrimary,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
