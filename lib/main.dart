import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app.dart';
import 'core/logging/app_log.dart';
import 'services/home_calendar_widget_service.dart';
import 'core/logging/logger_to_server.dart';
import 'core/storage/secure_store.dart';
import 'models/frequency_config.dart';
import 'models/user_goal.dart';
import 'services/dialog_service.dart';
import 'services/reminder_service.dart';
import 'views/widgets/add_edit_goal_dialog.dart';
import 'views/widgets/archive_bottom_sheet.dart';
import 'views/widgets/frequency_dialog.dart';
import 'views/widgets/goal_selection_sheet.dart';

void _setupDialogService() {
  final dialogService = DialogService();
  dialogService.registerDialogBuilder(DialogType.frequencyConfig, (
    context,
    data,
  ) {
    return FrequencyDialogWidget(initialConfig: data as FrequencyConfig);
  });
  dialogService.registerDialogBuilder(DialogType.addEditGoal, (context, data) {
    return AddEditGoalDialogWidget(existingGoal: data as UserGoal?);
  });
  dialogService.registerSheetBuilder(BottomSheetType.goalSelection, (
    context,
    data,
  ) {
    return GoalSelectionSheetWidget(currentTargetGoal: data as String? ?? '');
  });
  dialogService.registerSheetBuilder(BottomSheetType.archive, (context, data) {
    return const ArchiveBottomSheet();
  });
}

Future<void> _setupLogging() async {
  await AppLog.setup(
    debug: kDebugMode,
    releaseSink: kDebugMode
        ? null
        : (await LoggerToServer.create(secureStore: SecureStore())).emit,
  );

  // Same role as MAUI `AppDomain.CurrentDomain.UnhandledException` → LogFatal.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.fatal(details.exceptionAsString(), details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.fatal(error.toString(), error, stack);
    return true;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupLogging();
  await initializeDateFormatting('en');
  await initializeDateFormatting('uk');
  await LiquidGlassWidgets.initialize();
  await ReminderService().init();
  _setupDialogService();
  if (!kIsWeb) {
    await HomeCalendarWidgetService.ensureInitialized();
  }
  runApp(const PrinciplesApp());
}
