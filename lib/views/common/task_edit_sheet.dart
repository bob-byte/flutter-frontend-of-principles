import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../../core/theme/task_theme_palette.dart';
import '../../core/utils/date_helpers.dart';
import '../../l10n/task_strings.dart';
import '../../models/ai_task_draft.dart';
import '../../models/task.dart';
import '../../models/task_priority.dart';
import '../../viewmodels/edit_task_viewmodel.dart';
import '../../viewmodels/schedule_draft.dart';
import '../../viewmodels/tasks_viewmodel.dart';
import '../widgets/schedule/schedule_bottom_sheet.dart';
import '../widgets/schedule/schedule_format.dart';
import 'app_loading_indicator.dart';
import 'expandable_bottom_sheet.dart';
import 'ok_hint_popover.dart';
import 'task_ai_assist_sheet.dart';
import 'theme_picker_section.dart';
import 'completion_check.dart';
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
  final isEdit = taskId != null;

  // Create opens immediately; edit uses in-memory seed then refreshes in bg.
  if (!isEdit) {
    editVm.prepareCreate(aiDraft: aiDraft);
    unawaited(editVm.ensureThemesLoaded());
  } else {
    await editVm.load(taskId: taskId, aiDraft: aiDraft, seed: seed);
  }
  if (!context.mounted) return null;

  // Для нового завдання без дати від AI — підставити дату з режиму списку.
  if (!isEdit && (aiDraft == null || !aiDraft.hasDueDate)) {
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

  if (isEdit) {
    editVm.onAutosaved = (task) {
      unawaited(tasksVm.upsertEditedTask(task));
    };
  }

  // Content-sized composer (pixel height), not screen-fraction detents.
  Task? result;
  try {
    result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _TaskEditSheetHost(taskId: taskId, theme: tasksVm.themeData);
      },
    );
  } finally {
    if (isEdit) {
      final flushed = await editVm.flushAutosave();
      result ??= flushed ?? editVm.lastAutosaved;
      editVm.onAutosaved = null;
      editVm.liveSave = false;
    }
  }

  return result;
}

/// Pins the composer above the keyboard. Uses the live inset while the IME is
/// open (so the suggestion bar does not leave a black gap), and only holds the
/// last height across a brief focus handoff when iOS reports inset = 0.
class _TaskEditSheetHost extends StatefulWidget {
  const _TaskEditSheetHost({required this.taskId, required this.theme});

  final String? taskId;
  final ThemeData theme;

  @override
  State<_TaskEditSheetHost> createState() => _TaskEditSheetHostState();
}

class _TaskEditSheetHostState extends State<_TaskEditSheetHost> {
  double _heldInset = 0;
  Timer? _clearInsetTimer;

  bool _focusIsInsideHost() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<_TaskEditSheetHostState>() != null;
  }

  void _scheduleClearHeldInset() {
    if (_clearInsetTimer != null) return;
    _clearInsetTimer = Timer(const Duration(milliseconds: 400), () {
      _clearInsetTimer = null;
      if (!mounted) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0 || _focusIsInsideHost()) {
        return;
      }
      setState(() => _heldInset = 0);
    });
  }

  @override
  void dispose() {
    _clearInsetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final focusedInside = _focusIsInsideHost();

    if (inset > 0) {
      // Follow the real keyboard (incl. suggestion bar) — never fight it.
      _heldInset = inset;
      _clearInsetTimer?.cancel();
      _clearInsetTimer = null;
    } else if (focusedInside) {
      // Focus still in the sheet but inset briefly 0 during field handoff.
      _clearInsetTimer?.cancel();
      _clearInsetTimer = null;
    } else {
      _scheduleClearHeldInset();
    }

    final bottomInset = inset > 0 ? inset : _heldInset;
    final maxHeight = media.size.height - bottomInset - media.padding.top - 24;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: MediaQuery(
        data: media.copyWith(viewInsets: EdgeInsets.zero),
        child: Theme(
          data: widget.theme,
          child: TaskEditSheet(taskId: widget.taskId, maxHeight: maxHeight),
        ),
      ),
    );
  }
}

class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({super.key, this.taskId, required this.maxHeight});

  final String? taskId;

  /// Maximum sheet height in logical pixels (above the keyboard).
  final double maxHeight;

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  static const _hasSeenTaskAiAssistHintKey = 'hasSeenTaskAiAssistHint';

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocus = FocusNode();
  final _aiHintController = SuperTooltipController();
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
        _maybeShowAiHint();
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
    _aiHintController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowAiHint() async {
    await showOkHintOnce(
      context: context,
      controller: _aiHintController,
      prefsKey: _hasSeenTaskAiAssistHintKey,
      skip: widget.taskId != null,
    );
  }

  Future<void> _openAiAssist(EditTaskViewModel vm) async {
    if (vm.isSaving) return;
    if (_aiHintController.isVisible) {
      await _aiHintController.hideTooltip();
    }
    if (!mounted) return;
    final aiDraft = await showTaskAiAssistSheet(context);
    if (!mounted || aiDraft == null) return;

    vm.applyAiDraft(aiDraft);
    _syncControllers(vm);
    if (_titleError && vm.title.trim().isNotEmpty) {
      setState(() => _titleError = false);
    }
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
    // Create only — edits persist live; use [_closeEdit] to dismiss.
    if (vm.isEditing) return;
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

  Future<void> _closeEdit(EditTaskViewModel vm) async {
    vm.setTitle(_titleController.text);
    vm.setDescription(_descriptionController.text);
    final saved = await vm.flushAutosave();
    if (!mounted) return;
    Navigator.of(context).pop(saved ?? vm.lastAutosaved);
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

    return Consumer<EditTaskViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          _controllersSynced = false;
          return _SheetSurface(
            palette: palette,
            child: const SizedBox(
              height: 180,
              child: AppLoadingIndicator(size: 72),
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

        return _SheetSurface(
          palette: palette,
          maxHeight: widget.maxHeight,
          // Taps on chips / add-subtask must not count as "outside" text fields.
          child: TextFieldTapRegion(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BottomSheetDragHandle(
                  color: palette.textMuted.withValues(alpha: 0.3),
                  width: 40,
                  topPadding: 8,
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              focusNode: _titleFocus,
                              autofocus: widget.taskId == null,
                              onTapOutside: (_) {},
                              scrollPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.sentences,
                              enableSuggestions: true,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: vm.isDone
                                    ? palette.textMuted
                                    : palette.textPrimary,
                                height: 1.35,
                                decoration: vm.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              decoration: _borderlessDecoration.copyWith(
                                hintText: strings.taskWhatNeedsToBeDone,
                                hintStyle: TextStyle(
                                  color: palette.textMuted.withValues(
                                    alpha: 0.75,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 17,
                                ),
                                suffixIcon: widget.taskId == null
                                    ? OkHintPopover(
                                        controller: _aiHintController,
                                        message:
                                            strings.taskAiAssistFirstVisitHint,
                                        okLabel: AppLocalizations.of(
                                          context,
                                        )!.okButton,
                                        direction: TooltipDirection.down,
                                        showOnTap: false,
                                        contentWidth: 240,
                                        child: Tooltip(
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
                          ),
                          if (vm.isEditing) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: vm.isDone
                                  ? strings.taskMarkIncomplete
                                  : strings.taskMarkCompleted,
                              child: CompletionCheckButton(
                                key: const Key('taskEditCompleteToggle'),
                                isDone: vm.isDone,
                                palette: palette,
                                size: 28,
                                iconSize: 18,
                                onToggle: vm.toggleCompleted,
                              ),
                            ),
                          ],
                        ],
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
                        onTapOutside: (_) {},
                        scrollPadding: const EdgeInsets.symmetric(vertical: 8),
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
                      const SizedBox(height: 12),
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
                      if (widget.taskId == null) ...[
                        const SizedBox(width: 12),
                        _SubmitButton(
                          palette: palette,
                          icon: Icons.arrow_upward_rounded,
                          isSaving: vm.isSaving,
                          tooltip: strings.taskAdd,
                          onPressed: vm.isSaving ? null : () => _save(vm),
                        ),
                      ] else ...[
                        const SizedBox(width: 12),
                        _SubmitButton(
                          palette: palette,
                          icon: Icons.check_rounded,
                          isSaving: false,
                          tooltip: strings.taskDone,
                          onPressed: () => _closeEdit(vm),
                        ),
                      ],
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
  const _SheetSurface({
    required this.palette,
    required this.child,
    this.maxHeight,
  });

  final TasksUiPalette palette;
  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final sheet = TasksGlassSheet(
      palette: palette,
      blur: 14,
      // Content defines height; outer ConstrainedBox caps in pixels.
      fillHeight: false,
      maxHeightFactor: 1,
      child: child,
    );
    if (maxHeight == null) return sheet;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: sheet,
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
        canRequestFocus: false,
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

  static const _menuOffset = Offset(0, -168);

  Future<void> _openMenu(BuildContext context) async {
    // Keep the active text field focused so the soft keyboard stays up.
    final focus = FocusManager.instance.primaryFocus;
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final scheme = Theme.of(context).colorScheme;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(_menuOffset, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + _menuOffset,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final menuFuture = showMenu<TaskPriority?>(
      context: context,
      position: position,
      initialValue: priority,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: null,
          // showMenu returns null for both cancel and this item.
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
    );
    // Popup route autofocuses; reclaim the field so the IME stays open.
    _restoreTextInput(focus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreTextInput(focus);
    });

    final selected = await menuFuture;
    if (selected != null) onSelected(selected);
    _restoreTextInput(focus);
  }

  void _restoreTextInput(FocusNode? focus) {
    if (focus == null || !focus.canRequestFocus) return;
    focus.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Avoid stealing focus from title/description/subtask fields.
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openMenu(context),
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
    required this.icon,
    required this.isSaving,
    required this.onPressed,
    this.tooltip,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final bool isSaving;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(24),
      blur: 0,
      tint: palette.primary.withValues(alpha: palette.isDark ? 0.88 : 0.92),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
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
                : Icon(icon, color: palette.onPrimary, size: 24),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
