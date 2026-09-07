import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/utils/date_helpers.dart';
import '../l10n/task_strings.dart';
import '../models/ai_task_draft.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../viewmodels/edit_task_viewmodel.dart';
import '../viewmodels/schedule_draft.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../views/widgets/schedule/schedule_bottom_sheet.dart';
import '../views/widgets/schedule/schedule_format.dart';
import 'app_loading_indicator.dart';
import 'task_ai_assist_sheet.dart';
import 'theme_picker_section.dart';
import 'task_subtasks_editor.dart';
import 'tasks_glass.dart';

Future<Task?> showTaskEditSheet(
  BuildContext context, {
  String? taskId,
  AiTaskDraft? aiDraft,
}) async {
  final tasksVm = context.read<TasksViewModel>();
  final editVm = context.read<EditTaskViewModel>();
  final seed = taskId == null ? null : tasksVm.taskById(taskId);

  // Create opens immediately; edit uses in-memory seed then refreshes in bg.
  if (taskId == null) {
    editVm.prepareCreate(aiDraft: aiDraft);
    unawaited(editVm.ensureThemesLoaded());
  } else {
    await editVm.load(taskId: taskId, aiDraft: aiDraft, seed: seed);
  }
  if (!context.mounted) return null;

  // Для нового завдання без дати від AI — підставити дату з режиму списку.
  if (taskId == null && (aiDraft == null || !aiDraft.hasDueDate)) {
    switch (tasksVm.listMode) {
      case TasksListMode.inbox:
        editVm.setHasDueDate(false);
      case TasksListMode.day:
        editVm.setHasDueDate(true);
        editVm.setDueDate(dateOnly(tasksVm.selectedDay));
      case TasksListMode.tomorrow:
        editVm.setHasDueDate(true);
        editVm.setDueDate(dateOnly(tomorrowDate()));
      case TasksListMode.today:
      case TasksListMode.completed:
        editVm.setHasDueDate(true);
        editVm.setDueDate(dateOnly(DateTime.now()));
    }
  }

  return showModalBottomSheet<Task>(
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
  bool _controllersSynced = false;

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
      if (!mounted) return;
      final vm = context.read<EditTaskViewModel>();
      _syncControllers(vm);
      if (widget.taskId == null) {
        _titleFocus.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _syncControllers(EditTaskViewModel vm) {
    if (_titleController.text != vm.title) {
      _titleController.text = vm.title;
    }
    if (_descriptionController.text != vm.description) {
      _descriptionController.text = vm.description;
    }
    _controllersSynced = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _openAiAssist(EditTaskViewModel vm) async {
    if (vm.isSaving) return;
    final aiDraft = await showTaskAiAssistSheet(context);
    if (!mounted || aiDraft == null) return;

    vm.applyAiDraft(aiDraft);
    _syncControllers(vm);
    setState(() {
      if (vm.themeMode != ThemePickerMode.none) {
        _optionsExpanded = true;
      }
      if (_titleError && vm.title.trim().isNotEmpty) {
        _titleError = false;
      }
    });
  }

  Future<void> _pickDate(EditTaskViewModel vm) async {
    final result = await showScheduleBottomSheet(
      context,
      initial: vm.hasDueDate
          ? vm.toScheduleDraft()
          : ScheduleDraft.defaults(showDuration: false),
      showDuration: false,
    );
    if (result != null) vm.applySchedule(result);
  }

  Future<void> _save(EditTaskViewModel vm) async {
    vm.setTitle(_titleController.text);
    vm.setDescription(_descriptionController.text);
    if (vm.title.trim().isEmpty) {
      setState(() => _titleError = true);
      _titleFocus.requestFocus();
      return;
    }
    final saved = await vm.save();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  void _onTitleChanged(EditTaskViewModel vm, String value) {
    vm.setTitle(value);
    if (_titleError && value.trim().isNotEmpty) {
      setState(() => _titleError = false);
    }
  }

  String _dateLabel(TaskStrings strings, EditTaskViewModel vm) {
    if (!vm.hasDueDate || vm.dueDate == null) return strings.taskNoDueDate;
    return formatScheduleChip(
      Task(
        id: vm.editingId ?? '0',
        title: vm.title,
        createdAt: DateTime.now(),
        dueDate: vm.dueDate,
        endDate: vm.endDate,
        allDay: vm.allDay,
      ),
      noDate: strings.taskNoDueDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    final palette = context.watch<TasksViewModel>().palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Consumer<EditTaskViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          _controllersSynced = false;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _SheetSurface(
              palette: palette,
              child: const SizedBox(
                height: 180,
                child: AppLoadingIndicator(size: 72),
              ),
            ),
          );
        }

        if (!_controllersSynced ||
            (!_titleFocus.hasFocus &&
                (_titleController.text != vm.title ||
                    _descriptionController.text != vm.description))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncControllers(vm);
          });
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
                          autofocus: widget.taskId == null,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          enableSuggestions: true,
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
                            suffixIcon: widget.taskId == null
                                ? Tooltip(
                                    message: strings.taskAiAssistTitle,
                                    child: GestureDetector(
                                      onTap: vm.isSaving
                                          ? null
                                          : () => _openAiAssist(vm),
                                      behavior: HitTestBehavior.opaque,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        size: 20,
                                        color: palette.primary,
                                      ),
                                    ),
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
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
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          enableSuggestions: true,
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
                        const SizedBox(height: 18),
                        TaskSubtasksEditor(
                          vm: vm,
                          palette: palette,
                          strings: strings,
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
                              onTap: () => _pickDate(vm),
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
    return TasksGlassSheet(palette: palette, blur: 14, child: child);
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
    final color = hasPriority
        ? priorityColor(priority!, scheme)
        : palette.textMuted;
    final label = hasPriority
        ? priority!.label(strings)
        : strings.taskPriorityNone;

    return PopupMenuButton<TaskPriority?>(
      initialValue: priority,
      onSelected: onSelected,
      offset: const Offset(0, -168),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          // PopupMenuButton treats a null result as cancel, not a selection.
          onTap: () => onSelected(null),
          child: Row(
            children: [
              Icon(
                Icons.remove_circle_outline,
                size: 16,
                color: palette.textMuted,
              ),
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
      blur: 0,
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
