import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../core/network/server_required_retry.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/recommended_goal.dart';
import '../models/recommended_habit.dart';
import '../models/user_goal.dart';
import '../services/ai_recommendation_service.dart';
import '../services/database_service.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/user_service.dart';
import '../viewmodels/edit_goal_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import 'common/app_liquid_background.dart';
import 'common/completion_burst.dart';
import 'common/ok_hint_popover.dart';
import 'common/themed_lottie.dart';
import 'edit_habit_view.dart';
import 'habit_detail_view.dart';

class EditGoalView extends StatefulWidget {
  const EditGoalView({super.key, this.goal});

  static const routeName = '/edit-goal';

  final UserGoal? goal;

  static Future<bool> open(BuildContext context, {UserGoal? goal}) {
    return Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            settings: RouteSettings(name: routeName, arguments: goal),
            builder: (_) => EditGoalView(goal: goal),
          ),
        )
        .then((saved) => saved ?? false);
  }

  @override
  State<EditGoalView> createState() => _EditGoalViewState();
}

class _EditGoalViewState extends State<EditGoalView> {
  static const _hasSeenGoalRecommendHintKey = 'hasSeenGoalRecommendHint';
  static const _hasSeenGoalGenerateHabitsHintKey =
      'hasSeenGoalGenerateHabitsHint';

  late final EditGoalViewModel _vm;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  final _recommendHintController = SuperTooltipController();
  final _generateHabitsHintController = SuperTooltipController();
  bool _allowPop = false;
  bool _popResult = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _vm = EditGoalViewModel(
      context.read<GoalService>(),
      database: context.read<DatabaseService>(),
      habitService: context.read<HabitService>(),
      aiRecommendationService: context.read<AiRecommendationService>(),
      userService: context.read<UserService>(),
      serverRetry: ServerRequiredRetry(),
      existingGoal: widget.goal,
    );
    _nameController = TextEditingController(text: _vm.name);
    _notesController = TextEditingController(text: _vm.notes);
    _vm.syncFrom(context.read<HabitProgressViewModel>().habits);
    _vm.refreshFromDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowAiHints();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _recommendHintController.dispose();
    _generateHabitsHintController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _maybeShowAiHints() async {
    final showedRecommend = await showOkHintOnce(
      context: context,
      controller: _recommendHintController,
      prefsKey: _hasSeenGoalRecommendHintKey,
    );
    if (!mounted || showedRecommend) return;
    await showOkHintOnce(
      context: context,
      controller: _generateHabitsHintController,
      prefsKey: _hasSeenGoalGenerateHabitsHintKey,
    );
  }

  Future<void> _leave() async {
    if (_leaving || _allowPop) return;
    _leaving = true;
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    var changed = _vm.hasChanges;
    if (_vm.name.trim().isNotEmpty && _vm.isDirty) {
      changed = await _vm.save() || changed;
    }
    if (!mounted) return;
    setState(() {
      _allowPop = true;
      _popResult = changed;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_popResult);
    });
  }

  Future<void> _save() async {
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    final l10n = AppLocalizations.of(context)!;
    final ok = await _vm.save();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fieldRequired)));
      return;
    }
    await _leave();
  }

  Future<void> _confirmArchive() async {
    final l10n = AppLocalizations.of(context)!;
    final archived = _vm.isArchived;
    final confirmed = await DialogService().showConfirmAsync(
      msg: archived ? l10n.unarchiveGoalMessage : l10n.archiveGoalMessage,
      title: archived ? l10n.unarchiveGoalQuestion : l10n.archiveGoalQuestion,
    );
    if (!confirmed || !mounted) return;
    await _vm.toggleArchived();
    if (!mounted) return;
    setState(() {
      _allowPop = true;
      _popResult = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<UserGoal?> _readyGoal() async {
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    final saved = await _vm.ensureSaved();
    if (saved != null || !mounted) return saved;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.goalNameRequired)),
    );
    return null;
  }

  Future<void> _reloadHabits() async {
    await _vm.refreshFromDatabase();
    if (!mounted) return;
    final habitVm = context.read<HabitProgressViewModel>();
    try {
      await habitVm.load(silent: true, syncRemote: false);
      _vm.syncFrom(habitVm.habits);
    } catch (e) {
      debugPrint('Refresh habits after goal edit failed: $e');
    }
  }

  Future<void> _createHabit() async {
    final saved = await _readyGoal();
    if (saved == null || !mounted) return;
    await EditHabitView.show(context, habit: _vm.draftHabit());
    if (!mounted) return;
    await _reloadHabits();
  }

  Future<void> _generateHabits() async {
    if (_generateHabitsHintController.isVisible) {
      await _generateHabitsHintController.hideTooltip();
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    if (_vm.name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.goalNameRequired)));
      return;
    }
    await _vm.generateHabits(
      culture: Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _recommendGoals() async {
    if (_recommendHintController.isVisible) {
      await _recommendHintController.hideTooltip();
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    final area = _vm.selectedLifeArea;
    if (area == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.goalRecommendAreaRequired)));
      return;
    }
    await _vm.recommendGoals(
      culture: Localizations.localeOf(context).languageCode,
      areaOfLifeLabel: lifeAreaLabel(l10n, area),
    );
  }

  void _applyGoalRecommendation(RecommendedGoal recommendation) {
    _vm.applyGoalRecommendation(recommendation);
    _nameController.text = _vm.name;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    if (_notesController.text.trim() != _vm.notes) {
      _notesController.text = _vm.notes;
      _notesController.selection = TextSelection.collapsed(
        offset: _notesController.text.length,
      );
    }
  }

  Future<void> _addRecommendation(RecommendedHabit recommended) async {
    final saved = await _vm.addRecommendedHabit(recommended);
    if (saved == null || !mounted) return;
    await _reloadHabits();
  }

  Future<void> _openHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;
    await Navigator.of(
      context,
    ).pushNamed(HabitDetailView.routeName, arguments: id);
    if (!mounted) return;
    await _reloadHabits();
  }

  Future<void> _toggleCompleted() async {
    final l10n = AppLocalizations.of(context)!;
    _vm.name = _nameController.text;
    _vm.notes = _notesController.text;
    final completed = !_vm.isCompleted;
    try {
      final ok = await _vm.toggleCompleted();
      if (!ok || !mounted) return;
      DialogService().showToast(
        completed ? l10n.goalMarkedCompleted : l10n.goalMarkedIncomplete,
      );
    } catch (_) {
      if (!mounted) return;
      DialogService().showToast(l10n.genericErrorOccurred);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return ChangeNotifierProvider<EditGoalViewModel>.value(
      value: _vm,
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final vm = _vm;
          return PopScope(
            canPop: _allowPop,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _leave();
            },
            child: GlassScaffold(
              background: const AppLiquidBackground(),
              extendBody: false,
              appBar: GlassAppBar(
                title: Text(
                  vm.isEditing ? l10n.editGoalTitle : l10n.addGoalTitle,
                ),
                leading: GlassIconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    _leave();
                  },
                ),
                actions: [
                  if (vm.canArchive)
                    GlassIconButton(
                      key: const Key('editGoalArchiveButton'),
                      icon: Icon(
                        vm.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      semanticLabel: vm.isArchived
                          ? l10n.unarchiveTooltip
                          : l10n.archiveTooltip,
                      onPressed: _confirmArchive,
                    ),
                ],
              ),
              body: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _IdentityCard(
                            palette: palette,
                            nameController: _nameController,
                            notesController: _notesController,
                            onNameChanged: vm.updateName,
                            onNotesChanged: vm.updateNotes,
                            canComplete: vm.canToggleCompleted,
                            isCompleted: vm.isCompleted,
                            onToggleCompleted: _toggleCompleted,
                          ),
                          const SizedBox(height: 22),
                          _GoalRecommendSection(
                            palette: palette,
                            selectedArea: vm.selectedLifeArea,
                            recommendations: vm.goalRecommendations,
                            isLoading: vm.isRecommendingGoals,
                            error: vm.recommendGoalsError,
                            hintController: _recommendHintController,
                            onSelectArea: vm.selectLifeArea,
                            onRecommend: _recommendGoals,
                            onApply: _applyGoalRecommendation,
                          ),
                          const SizedBox(height: 22),
                          _HabitsSection(
                            palette: palette,
                            habits: vm.habits,
                            recommendations: vm.recommendations,
                            isGenerating: vm.isGenerating,
                            generateError: vm.generateError,
                            generateHintController:
                                _generateHabitsHintController,
                            onCreate: _createHabit,
                            onGenerate: _generateHabits,
                            onAddRecommendation: _addRecommendation,
                            onOpenHabit: _openHabit,
                          ),
                        ],
                      ),
                    ),
                    _SaveBar(isSaving: vm.isSaving, onSave: _save),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.palette,
    required this.nameController,
    required this.notesController,
    required this.onNameChanged,
    required this.onNotesChanged,
    required this.canComplete,
    required this.isCompleted,
    required this.onToggleCompleted,
  });

  final TasksUiPalette palette;
  final TextEditingController nameController;
  final TextEditingController notesController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onNotesChanged;
  final bool canComplete;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: palette.cardBorder.withValues(
            alpha: palette.isDark ? 0.45 : 0.7,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(
              alpha: palette.isDark ? 0.22 : 0.10,
            ),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(gradient: palette.primaryGradient),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.onPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_rounded, color: palette.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.goalNameLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.onPrimary,
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: TextField(
                    key: const Key('goalNameField'),
                    controller: nameController,
                    autofocus: nameController.text.isEmpty,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 255,
                    minLines: 1,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.25,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.goalNameLabel,
                      prefixIcon: const Icon(Icons.flag_outlined),
                      filled: true,
                      fillColor: palette.softBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                    onChanged: onNameChanged,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: TextField(
                    key: const Key('goalNotesField'),
                    controller: notesController,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(color: palette.textPrimary, height: 1.35),
                    decoration: InputDecoration(
                      labelText: l10n.goalNotes,
                      prefixIcon: const Icon(Icons.notes_rounded),
                      filled: true,
                      fillColor: palette.softBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: onNotesChanged,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.goalExamplesHint,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: palette.textMuted,
                  ),
                ),
                if (canComplete) ...[
                  const SizedBox(height: 14),
                  _CompleteButton(
                    palette: palette,
                    isCompleted: isCompleted,
                    onPressed: onToggleCompleted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.palette,
    required this.isCompleted,
    required this.onPressed,
  });

  final TasksUiPalette palette;
  final bool isCompleted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Builder(
      builder: (iconContext) {
        return OutlinedButton.icon(
          key: const Key('goalCompleteButton'),
          onPressed: () {
            if (!isCompleted) {
              playCompletionCelebration(
                iconContext,
                color: theme.colorScheme.primary,
                checkSize: 24,
                radius: 40,
              );
            }
            onPressed();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.primary,
            side: BorderSide(color: palette.primary.withValues(alpha: 0.45)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: CompletionCelebrate(
            isCompleted: isCompleted,
            color: palette.primary,
            burstRadius: 40,
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.check_circle_outline,
            ),
          ),
          label: Text(
            isCompleted ? l10n.markGoalIncomplete : l10n.markGoalCompleted,
          ),
        );
      },
    );
  }
}

String lifeAreaLabel(AppLocalizations l10n, LifeArea area) {
  return switch (area) {
    LifeArea.spirituality => l10n.lifeAreaSpirituality,
    LifeArea.character => l10n.lifeAreaCharacter,
    LifeArea.health => l10n.lifeAreaHealth,
    LifeArea.career => l10n.lifeAreaCareer,
    LifeArea.family => l10n.lifeAreaFamily,
    LifeArea.relationships => l10n.lifeAreaRelationships,
    LifeArea.sociality => l10n.lifeAreaSociality,
    LifeArea.mentality => l10n.lifeAreaMentality,
    LifeArea.other => l10n.lifeAreaOther,
  };
}

class _GoalRecommendSection extends StatelessWidget {
  const _GoalRecommendSection({
    required this.palette,
    required this.selectedArea,
    required this.recommendations,
    required this.isLoading,
    required this.error,
    required this.hintController,
    required this.onSelectArea,
    required this.onRecommend,
    required this.onApply,
  });

  final TasksUiPalette palette;
  final LifeArea? selectedArea;
  final List<RecommendedGoal> recommendations;
  final bool isLoading;
  final String? error;
  final SuperTooltipController hintController;
  final ValueChanged<LifeArea?> onSelectArea;
  final VoidCallback onRecommend;
  final ValueChanged<RecommendedGoal> onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.goalRecommendSection,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.goalRecommendLead,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.goalRecommendAreaLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final area in LifeArea.values)
              ChoiceChip(
                key: Key('lifeAreaChip_${area.name}'),
                label: Text(lifeAreaLabel(l10n, area)),
                selected: selectedArea == area,
                onSelected: (selected) {
                  onSelectArea(selected ? area : null);
                },
                selectedColor: palette.primary.withValues(alpha: 0.22),
                labelStyle: TextStyle(
                  color: selectedArea == area
                      ? palette.primary
                      : palette.textPrimary,
                  fontWeight: selectedArea == area
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selectedArea == area
                      ? palette.primary.withValues(alpha: 0.55)
                      : palette.cardBorder.withValues(
                          alpha: palette.isDark ? 0.45 : 0.7,
                        ),
                ),
                backgroundColor: palette.softBg,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: OkHintPopover(
                    controller: hintController,
                    message: l10n.goalRecommendFirstVisitHint,
                    okLabel: l10n.okButton,
                    showOnTap: false,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned.fill(
                child: OutlinedButton.icon(
                  key: const Key('goalRecommendButton'),
                  onPressed: isLoading ? null : onRecommend,
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        )
                      : Icon(Icons.auto_awesome, color: palette.primary),
                  label: Text(
                    l10n.goalRecommendButton,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading) ...[
          const SizedBox(height: 8),
          Text(
            l10n.goalRecommendLoadingHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
          ),
        ],
        if (error != null && error!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (var i = 0; i < recommendations.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _GoalRecommendationCard(
              palette: palette,
              recommendation: recommendations[i],
              applyLabel: l10n.goalRecommendApply,
              onApply: () => onApply(recommendations[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _GoalRecommendationCard extends StatelessWidget {
  const _GoalRecommendationCard({
    required this.palette,
    required this.recommendation,
    required this.applyLabel,
    required this.onApply,
  });

  final TasksUiPalette palette;
  final RecommendedGoal recommendation;
  final String applyLabel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.cardBorder.withValues(
            alpha: palette.isDark ? 0.4 : 0.65,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            recommendation.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
              height: 1.3,
            ),
          ),
          if (recommendation.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              recommendation.reason,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: palette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('goalRecommendApply_${recommendation.name}'),
              onPressed: onApply,
              icon: Icon(Icons.check_rounded, color: palette.primary, size: 18),
              label: Text(
                applyLabel,
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitsSection extends StatelessWidget {
  const _HabitsSection({
    required this.palette,
    required this.habits,
    required this.recommendations,
    required this.isGenerating,
    required this.generateError,
    required this.generateHintController,
    required this.onCreate,
    required this.onGenerate,
    required this.onAddRecommendation,
    required this.onOpenHabit,
  });

  final TasksUiPalette palette;
  final List<Habit> habits;
  final List<RecommendedHabit> recommendations;
  final bool isGenerating;
  final String? generateError;
  final SuperTooltipController generateHintController;
  final VoidCallback onCreate;
  final VoidCallback onGenerate;
  final ValueChanged<RecommendedHabit> onAddRecommendation;
  final ValueChanged<Habit> onOpenHabit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.goalHabitsSection,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (habits.isNotEmpty)
              Text(
                l10n.goalHabitsCount(habits.length),
                style: TextStyle(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.goalPageLead,
          style: TextStyle(color: palette.textMuted, height: 1.35),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActionCard(
                  key: const Key('goalCreateHabit'),
                  palette: palette,
                  icon: Icons.add_rounded,
                  title: l10n.goalCreateHabit,
                  subtitle: l10n.goalCreateHabitHint,
                  onTap: onCreate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: OkHintPopover(
                          controller: generateHintController,
                          message: l10n.goalGenerateHabitsFirstVisitHint,
                          okLabel: l10n.okButton,
                          showOnTap: false,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _ActionCard(
                        key: const Key('goalGenerateHabits'),
                        palette: palette,
                        icon: Icons.auto_awesome_rounded,
                        title: l10n.goalGenerateHabits,
                        subtitle: l10n.goalGenerateHabitsHint,
                        emphasized: true,
                        busy: isGenerating,
                        onTap: isGenerating ? null : onGenerate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isGenerating) ...[
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: palette.primary.withValues(
                  alpha: palette.isDark ? 0.12 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: ThemedLottie.fire(width: 84, height: 84),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recommendedHabitsLoadingHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, height: 1.35),
          ),
        ],
        if (generateError != null) ...[
          const SizedBox(height: 14),
          Text(
            generateError!,
            style: TextStyle(color: palette.textPrimary, height: 1.35),
          ),
        ],
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final recommendation in recommendations) ...[
            _RecommendationCard(
              palette: palette,
              recommendation: recommendation,
              onAdd: () => onAddRecommendation(recommendation),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        if (habits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.goalHabitsEmpty,
              style: TextStyle(color: palette.textMuted, height: 1.35),
            ),
          )
        else
          for (final habit in habits) ...[
            _HabitCard(
              palette: palette,
              habit: habit,
              onTap: () => onOpenHabit(habit),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
    this.busy = false,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized ? palette.onPrimary : palette.textPrimary;
    final muted = emphasized
        ? palette.onPrimary.withValues(alpha: 0.82)
        : palette.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: emphasized ? palette.primaryGradient : null,
            color: emphasized ? null : palette.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: emphasized
                ? null
                : Border.all(
                    color: palette.cardBorder.withValues(
                      alpha: palette.isDark ? 0.4 : 0.65,
                    ),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: emphasized
                        ? palette.onPrimary.withValues(alpha: 0.18)
                        : palette.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: emphasized
                              ? palette.onPrimary
                              : palette.primary,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.3, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.palette,
    required this.recommendation,
    required this.onAdd,
  });

  final TasksUiPalette palette;
  final RecommendedHabit recommendation;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.primary.withValues(
            alpha: palette.isDark ? 0.35 : 0.22,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (recommendation.reasonToFollow.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    recommendation.reasonToFollow,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onAdd, child: Text(l10n.goalAddRecommendation)),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.palette,
    required this.habit,
    required this.onTap,
  });

  final TasksUiPalette palette;
  final Habit habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.cardBorder.withValues(
                alpha: palette.isDark ? 0.35 : 0.55,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  habit.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          key: const Key('goalSaveButton'),
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            disabledBackgroundColor: palette.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: isSaving
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.onPrimary,
                  ),
                )
              : Text(
                  l10n.saveButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
