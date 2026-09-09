import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../core/road_guide/road_guide_controller.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit.dart';
import '../viewmodels/edit_habit_viewmodel.dart';
import '../viewmodels/schedule_draft.dart';
import '../widgets/app_liquid_background.dart';
import 'widgets/recommended_habits_sheet.dart';
import 'widgets/schedule/schedule_bottom_sheet.dart';
import 'widgets/schedule/schedule_format.dart';

class EditHabitView extends StatefulWidget {
  const EditHabitView({super.key, this.habit});

  static const routeName = '/edit-habit';

  final Habit? habit;

  static Future<void> show(BuildContext context, {Habit? habit}) {
    context.read<EditHabitViewModel>().init(habit);
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: routeName, arguments: habit),
        builder: (_) => EditHabitView(habit: habit),
      ),
    );
  }

  @override
  State<EditHabitView> createState() => _EditHabitViewState();
}

class _EditHabitViewState extends State<EditHabitView> {
  static const _hasSeenRecommendedHabitsHintKey =
      'hasSeenRecommendedHabitsHint';

  final _nameTooltipController = SuperTooltipController();
  final _difficultyTooltipController = SuperTooltipController();
  final _recommendedHabitsTooltipController = SuperTooltipController();
  final _flexibleTooltipController = SuperTooltipController();
  final _noExceptionsTooltipController = SuperTooltipController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final vm = context.read<EditHabitViewModel>()..init(widget.habit);
    _nameController.text = vm.habitName;
    _notesController.text = vm.notes;
    _maybeShowRecommendedHabitsHint();
  }

  @override
  void dispose() {
    _nameTooltipController.dispose();
    _difficultyTooltipController.dispose();
    _recommendedHabitsTooltipController.dispose();
    _flexibleTooltipController.dispose();
    _noExceptionsTooltipController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.read<EditHabitViewModel>();
    // MAUI copies the name from the editor before save because the bound
    // value is not updated on some devices (hardware keyboard / IME).
    vm.habitName = _nameController.text;
    vm.notes = _notesController.text;
    final success = await vm.saveHabit();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.fieldRequired)));
  }

  Future<void> _openHabitSchedule(EditHabitViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    // Keep reminder description default in sync with the name field.
    vm.habitName = _nameController.text;
    final habit = Habit(
      name: vm.habitName,
      frequency: vm.frequency,
      reminders: vm.reminders,
      constantReminder: vm.constantReminder,
    );
    final initial = vm.reminders.isEmpty
        ? ScheduleDraft.defaults(showRepeat: false, showDateDuration: false)
        : ScheduleDraft.fromHabit(habit);
    await vm.seedReminderCopyDefaults(
      initial,
      personalityFallbackTitle: l10n.becomeTruePersonalityTitle,
    );
    if (!mounted) return;
    final result = await showScheduleBottomSheet(
      context,
      initial: initial,
      showRepeat: false,
      showDateDuration: false,
    );
    if (result != null) {
      vm.applySchedule(result, reminderFallbackTitle: l10n.habitReminder);
    }
  }

  Future<void> _maybeShowRecommendedHabitsHint() async {
    try {
      if (context.read<RoadGuideController>().isActive) return;
    } on ProviderNotFoundException {
      // Widget tests may mount without the road guide.
    }
    final vm = context.read<EditHabitViewModel>();
    if (!vm.isNewHabit) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hasSeenRecommendedHabitsHintKey) ?? false) return;

    await _waitUntilPageReady();
    if (!mounted) return;

    await prefs.setBool(_hasSeenRecommendedHabitsHintKey, true);
    await _recommendedHabitsTooltipController.showTooltip();
  }

  Future<void> _waitUntilPageReady() async {
    await WidgetsBinding.instance.endOfFrame;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _selectHabitType({required bool flexible}) async {
    context.read<EditHabitViewModel>().setFlexible(flexible);
    final toShow = flexible
        ? _flexibleTooltipController
        : _noExceptionsTooltipController;
    final toHide = flexible
        ? _noExceptionsTooltipController
        : _flexibleTooltipController;
    if (toHide.isVisible) {
      await toHide.hideTooltip();
    }
    if (!mounted) return;
    await toShow.showTooltip();
  }

  Future<void> _recommendHabits() async {
    if (_recommendedHabitsTooltipController.isVisible) {
      await _recommendedHabitsTooltipController.hideTooltip();
    }
    if (!mounted) return;
    final vm = context.read<EditHabitViewModel>();
    final shouldShow = await vm.requestRecommendedHabits(
      culture: Localizations.localeOf(context).languageCode,
    );
    if (!shouldShow || !mounted) return;

    final selected = await RecommendedHabitsSheet.show(context);
    if (selected == null || !mounted) return;

    vm.applyRecommendedHabit(selected);
    _nameController.text = vm.habitName;
    _notesController.text = vm.notes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.watch<ThemeController>().palette;
    final vm = context.watch<EditHabitViewModel>();
    final automationHelp = vm.automationHelpText(l10n);
    final primaryBrightness = ThemeData.estimateBrightnessForColor(
      palette.primary,
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: primaryBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: primaryBrightness,
        ),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.onPrimary.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_left, color: palette.onPrimary),
          ),
        ),
        title: Text(
          l10n.habitScreenTitle,
          style: TextStyle(
            color: palette.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: (val) => vm.habitName = val,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.habitNameField,
                        prefixIcon: const Icon(Icons.local_fire_department),
                        suffixIcon: _InfoTooltip(
                          controller: _nameTooltipController,
                          message: l10n.habitNameInfo,
                          okLabel: l10n.okButton,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SelectField(
                      label: l10n.habitGoalLabel,
                      value: vm.targetGoal,
                      icon: Icons.track_changes,
                      emphasized: vm.targetGoal.isNotEmpty,
                      onTap: vm.requestGoalSelection,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeButton(
                            label: l10n.habitFlexible,
                            icon: Icons.alt_route,
                            selected: vm.isFlexible,
                            tooltipController: _flexibleTooltipController,
                            tooltipMessage: l10n.habitFlexibleInfo,
                            okLabel: l10n.okButton,
                            onPressed: () => _selectHabitType(flexible: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TypeButton(
                            label: l10n.habitNoExceptions,
                            icon: Icons.gavel,
                            selected: !vm.isFlexible,
                            tooltipController: _noExceptionsTooltipController,
                            tooltipMessage: l10n.habitNoExceptionsInfo,
                            okLabel: l10n.okButton,
                            onPressed: () => _selectHabitType(flexible: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SelectField(
                      label: l10n.habitFrequency,
                      value: vm.frequency.displayString,
                      icon: Icons.loop,
                      onTap: vm.requestFrequencyConfig,
                    ),
                    const SizedBox(height: 16),
                    _SelectField(
                      label: l10n.habitReminder,
                      value: vm.reminders.isNotEmpty
                          ? formatHabitReminderSummary(vm.reminders, [
                              l10n.weekdayMon,
                              l10n.weekdayTue,
                              l10n.weekdayWed,
                              l10n.weekdayThu,
                              l10n.weekdayFri,
                              l10n.weekdaySat,
                              l10n.weekdaySun,
                            ])
                          : '',
                      icon: Icons.notifications_none,
                      onTap: () => _openHabitSchedule(vm),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 96,
                      child: TextField(
                        controller: _notesController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.center,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (val) => vm.notes = val,
                        decoration: InputDecoration(
                          labelText: l10n.habitNotes,
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.habitDifficulty,
                        prefixIcon: const Icon(Icons.bar_chart),
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 0,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${vm.difficulty}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove),
                              onPressed: vm.decrementDifficulty,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add),
                              onPressed: vm.incrementDifficulty,
                            ),
                            _InfoTooltip(
                              controller: _difficultyTooltipController,
                              message: l10n.habitDifficultyInfo,
                              okLabel: l10n.okButton,
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const SizedBox(width: double.infinity, height: 24),
                    ),
                    if (automationHelp.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Text(
                          automationHelp,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vm.isNewHabit) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Text(
                        vm.targetGoal.trim().isEmpty
                            ? l10n.recommendedHabitsCaptionNoGoal
                            : l10n.recommendedHabitsCaptionWithGoal(
                                vm.targetGoal.trim(),
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _HabitInfoPopover(
                                controller: _recommendedHabitsTooltipController,
                                message: vm.targetGoal.trim().isEmpty
                                    ? l10n.recommendedHabitsCaptionNoGoal
                                    : l10n.recommendedHabitsGoalPopover(
                                        vm.targetGoal.trim(),
                                      ),
                                okLabel: l10n.okButton,
                                showOnTap: false,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: OutlinedButton(
                              key: context
                                  .read<RoadGuideController>()
                                  .keys
                                  .recommendedHabits,
                              onPressed: vm.isSaving ? null : _recommendHabits,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.primary,
                                side: BorderSide(color: scheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: vm.isRecommendedHabitsLoading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: scheme.primary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      l10n.recommendedHabitsButton,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: vm.isSaving
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: scheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.saveButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [const AppLiquidBackground(), scaffold],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.tooltipController,
    required this.tooltipMessage,
    required this.okLabel,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final SuperTooltipController tooltipController;
  final String tooltipMessage;
  final String okLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _HabitInfoPopover(
              controller: tooltipController,
              message: tooltipMessage,
              okLabel: okLabel,
              direction: TooltipDirection.down,
              showOnTap: false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: selected
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            icon: Icon(icon, size: 18),
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = value.trim().isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: isEmpty,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.more_horiz),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          isEmpty ? ' ' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            color: emphasized ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _HabitInfoPopover extends StatelessWidget {
  const _HabitInfoPopover({
    required this.controller,
    required this.message,
    required this.okLabel,
    required this.child,
    this.direction = TooltipDirection.up,
    this.showOnTap = true,
  });

  final SuperTooltipController controller;
  final String message;
  final String okLabel;
  final Widget child;
  final TooltipDirection direction;
  final bool showOnTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SuperTooltip(
      controller: controller,
      style: TooltipStyle(backgroundColor: scheme.primary, hasShadow: false),
      positionConfig: PositionConfiguration(preferredDirection: direction),
      interactionConfig: InteractionConfiguration(showOnTap: showOnTap),
      content: SizedBox(
        width: 280,
        child: Material(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 13),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: () => controller.hideTooltip(),
                child: Text(
                  okLabel,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}

class _InfoTooltip extends StatelessWidget {
  const _InfoTooltip({
    required this.controller,
    required this.message,
    required this.okLabel,
  });

  final SuperTooltipController controller;
  final String message;
  final String okLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: _HabitInfoPopover(
        controller: controller,
        message: message,
        okLabel: okLabel,
        child: IconButton(
          icon: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
          onPressed: () => controller.showTooltip(),
        ),
      ),
    );
  }
}
