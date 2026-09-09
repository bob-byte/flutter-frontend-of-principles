import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/user_goal.dart';
import '../../services/dialog_service.dart';
import '../../services/goal_service.dart';
import '../../viewmodels/add_edit_goal_viewmodel.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/completion_burst.dart';

class AddEditGoalDialogWidget extends StatelessWidget {
  final UserGoal? existingGoal;

  const AddEditGoalDialogWidget({super.key, this.existingGoal});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AddEditGoalViewModel(
        ctx.read<GoalService>(),
        existingGoal: existingGoal,
      ),
      child: const _AddEditGoalDialogContent(),
    );
  }
}

class _AddEditGoalDialogContent extends StatefulWidget {
  const _AddEditGoalDialogContent();

  @override
  State<_AddEditGoalDialogContent> createState() =>
      _AddEditGoalDialogContentState();
}

class _AddEditGoalDialogContentState extends State<_AddEditGoalDialogContent> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final vm = context.read<AddEditGoalViewModel>();
    _controller = TextEditingController(text: vm.text)
      ..selection = TextSelection.collapsed(offset: vm.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddEditGoalViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = vm.existingGoal != null;

    return AppAlertDialog(
      title: Text(isEditing ? l10n.editGoalTitle : l10n.addGoalTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('goalDialogFieldInput'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '${vm.text.length}/255',
                suffixIcon: vm.canToggleCompleted
                    ? Builder(
                        builder: (iconContext) {
                          return IconButton(
                            key: const Key('goalDialogComplete'),
                            tooltip: vm.isCompleted
                                ? l10n.markGoalIncomplete
                                : l10n.markGoalCompleted,
                            onPressed: () {
                              if (!vm.isCompleted) {
                                playCompletionCelebration(
                                  iconContext,
                                  color: theme.colorScheme.primary,
                                  checkSize: 24,
                                  radius: 40,
                                );
                              }
                              _toggleCompleted(context, vm, l10n);
                            },
                            icon: CompletionCelebrate(
                              isCompleted: vm.isCompleted,
                              color: theme.colorScheme.primary,
                              burstRadius: 40,
                              child: Icon(
                                vm.isCompleted
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
              onChanged: vm.updateText,
              maxLength: 255,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (vm.text.trim().isNotEmpty) {
                  vm.saveGoal();
                }
              },
            ),
            const SizedBox(height: 12),
            Text(l10n.goalExamplesHint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: vm.cancel, child: Text(l10n.cancelButton)),
        TextButton(
          key: const Key('goalDialogSave'),
          onPressed: vm.text.trim().isNotEmpty ? vm.saveGoal : null,
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }

  Future<void> _toggleCompleted(
    BuildContext context,
    AddEditGoalViewModel vm,
    AppLocalizations l10n,
  ) async {
    try {
      await vm.toggleCompleted();
      if (!context.mounted) return;
      DialogService().showToast(
        vm.isCompleted ? l10n.goalMarkedCompleted : l10n.goalMarkedIncomplete,
      );
    } catch (_) {
      if (!context.mounted) return;
      DialogService().showToast(l10n.genericErrorOccurred);
    }
  }
}
