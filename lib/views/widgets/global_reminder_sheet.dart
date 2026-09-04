import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../services/dialog_service.dart';
import '../../services/reminder_service.dart';
import '../../services/user_service.dart';
import '../../viewmodels/global_reminder_viewmodel.dart';
import '../../widgets/app_loading_indicator.dart';

class GlobalReminderBottomSheet extends StatelessWidget {
  const GlobalReminderBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ChangeNotifierProvider(
          create: (c) => GlobalReminderViewModel(
            reminderService: c.read<ReminderService>(),
            userService: c.read<UserService>(),
          ),
          child: const GlobalReminderBottomSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _GlobalReminderSheetContent();
  }
}

class _GlobalReminderSheetContent extends StatefulWidget {
  const _GlobalReminderSheetContent();

  @override
  State<_GlobalReminderSheetContent> createState() =>
      _GlobalReminderSheetContentState();
}

class _GlobalReminderSheetContentState
    extends State<_GlobalReminderSheetContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final vm = context.read<GlobalReminderViewModel>();
      await vm.load(
        defaultTitle: l10n.habitsReportReminderTitleText,
        defaultDescription: l10n.habitsReportReminderDescriptionText,
      );
      if (!mounted) return;
      _titleController.text = vm.reminder.title;
      _descController.text = vm.reminder.description;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(GlobalReminderViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.read<ThemeController>().palette;
    await showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n.doneButton,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      0,
                      0,
                      0,
                      vm.time.hour,
                      vm.time.minute,
                    ),
                    onDateTimeChanged: (DateTime newTime) {
                      vm.setTime(
                        TimeOfDay(hour: newTime.hour, minute: newTime.minute),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(GlobalReminderViewModel vm) async {
    final result = await vm.save(
      title: _titleController.text,
      description: _descController.text,
    );
    if (!mounted) return;
    if (result == GlobalReminderSaveResult.notificationsDenied) {
      await DialogService().promptOpenNotificationSettings();
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GlobalReminderViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return Material(
      color: palette.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.habitReminder,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            if (vm.isLoading)
              const AppLoadingIndicator(
                size: 72,
                padding: EdgeInsets.symmetric(vertical: 24),
              )
            else ...[
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.reminderTitleLabel,
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.reminderDescriptionLabel,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(vm),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.reminderTimeLabel,
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    vm.time.format(context),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: vm.isEnabled,
                    onChanged: vm.setEnabled,
                    activeTrackColor: palette.primary,
                  ),
                  Text(
                    l10n.reminderEnableLabel,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: palette.textMuted.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: palette.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            l10n.cancelButton,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: vm.isSaving ? null : () => _save(vm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            l10n.saveButton,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
