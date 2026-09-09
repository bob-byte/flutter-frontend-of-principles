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
import '../../widgets/expandable_bottom_sheet.dart';
import '../../widgets/tasks_glass.dart';

class GlobalReminderBottomSheet {
  const GlobalReminderBottomSheet._();

  /// Returns `true` when the user saved successfully.
  static Future<bool> show(BuildContext context) async {
    final palette = context.read<ThemeController>().palette;
    final saved = await showExpandableModalBottomSheet<bool>(
      context: context,
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: ExpandableSheetDefaults.maxChildSize,
      builder: (ctx, scrollController) => ChangeNotifierProvider(
        create: (c) => GlobalReminderViewModel(
          reminderService: c.read<ReminderService>(),
          userService: c.read<UserService>(),
        ),
        child: TasksGlassSheet(
          palette: palette,
          fillHeight: true,
          child: _GlobalReminderSheetContent(
            scrollController: scrollController,
          ),
        ),
      ),
    );
    return saved == true;
  }
}

class _GlobalReminderSheetContent extends StatefulWidget {
  const _GlobalReminderSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_GlobalReminderSheetContent> createState() =>
      _GlobalReminderSheetContentState();
}

class _GlobalReminderSheetContentState
    extends State<_GlobalReminderSheetContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  bool _customizeExpanded = false;
  bool _customizeInitialized = false;

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
      setState(() {
        _customizeExpanded = !vm.matchesDefaults(
          vm.reminder.title,
          vm.reminder.description,
        );
        _customizeInitialized = true;
      });
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return TasksGlassSheet(
          palette: palette,
          maxHeightFactor: 0.42,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
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
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: palette.isDark
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: MediaQuery.of(
                        context,
                      ).alwaysUse24HourFormat,
                      initialDateTime: DateTime(
                        2000,
                        1,
                        1,
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
    final l10n = AppLocalizations.of(context)!;
    if (result == GlobalReminderSaveResult.notSupported) {
      await DialogService().showErrorAsync(
        l10n.deviceDoesNotSupportNotifications,
      );
      return;
    }
    if (result == GlobalReminderSaveResult.notificationsDenied) {
      await DialogService().promptOpenNotificationSettings();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final timeLabel = vm.time.format(context);
    Navigator.pop(context, true);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          vm.isEnabled
              ? l10n.habitsReportReminderSavedOn(timeLabel)
              : l10n.habitsReportReminderSavedOff,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GlobalReminderViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final palette = context.watch<ThemeController>().palette;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BottomSheetDragHandle(
              color: palette.textMuted.withValues(alpha: 0.35),
              bottomPadding: 16,
            ),
            Text(
              l10n.habitsReportReminderSheetTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.habitsReportReminderSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
            const SizedBox(height: 20),
            if (vm.isLoading || !_customizeInitialized)
              const AppLoadingIndicator(
                size: 72,
                padding: EdgeInsets.symmetric(vertical: 24),
              )
            else ...[
              TasksGlassPanel(
                palette: palette,
                blur: 0,
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectTime(vm),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: palette.accentMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.reminderTimeLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      vm.time.format(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TasksGlassPanel(
                palette: palette,
                blur: 0,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.reminderEnableLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: vm.isEnabled,
                      onChanged: vm.setEnabled,
                      activeTrackColor: palette.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () =>
                    setState(() => _customizeExpanded = !_customizeExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _customizeExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: palette.accentMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.habitsReportReminderCustomize,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  // Leave room for OutlineInputBorder floating labels.
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.reminderTitleLabel,
                          prefixIcon: const Icon(Icons.local_offer_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: l10n.reminderDescriptionLabel,
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                crossFadeState: _customizeExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: palette.glassChipFill,
                        foregroundColor: palette.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: vm.isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: Text(
                        l10n.cancelButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      onPressed: vm.isSaving || vm.isLoading
                          ? null
                          : () => _save(vm),
                      child: Text(
                        l10n.saveButton,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
