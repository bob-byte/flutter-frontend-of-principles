import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/reminder_service.dart';
import 'services/dialog_service.dart';
import 'views/widgets/frequency_dialog.dart';
import 'views/widgets/add_edit_goal_dialog.dart';
import 'views/widgets/goal_selection_sheet.dart';
import 'models/frequency_config.dart';
import 'models/user_goal.dart';
import 'views/widgets/archive_bottom_sheet.dart';

void _setupDialogService() {
  final dialogService = DialogService();
  dialogService.registerDialogBuilder(DialogType.frequencyConfig, (context, data) {
    return FrequencyDialogWidget(initialConfig: data as FrequencyConfig);
  });
  dialogService.registerDialogBuilder(DialogType.addEditGoal, (context, data) {
    return AddEditGoalDialogWidget(existingGoal: data as UserGoal?);
  });
  dialogService.registerSheetBuilder(BottomSheetType.goalSelection, (context, data) {
    return GoalSelectionSheetWidget(currentTargetGoal: data as String? ?? '');
  });
  dialogService.registerSheetBuilder(BottomSheetType.archive, (context, data) {
    return const ArchiveBottomSheet();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService().init();
  _setupDialogService();
  runApp(const PrinciplesApp());
}
