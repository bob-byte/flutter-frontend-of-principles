import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../models/habit_reminder.dart';
import '../../services/dialog_service.dart';
import '../../services/reminder_service.dart';
import '../../models/habit.dart'; // Needed if we want to pass Habit

class ReminderBottomSheet extends StatefulWidget {
  final HabitReminder? initialReminder;
  final Habit habit;

  const ReminderBottomSheet({
    super.key,
    this.initialReminder,
    required this.habit,
  });

  static Future<HabitReminder?> show(
    BuildContext context,
    Habit habit, {
    HabitReminder? initialReminder,
  }) {
    return showModalBottomSheet<HabitReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ReminderBottomSheet(
          initialReminder: initialReminder,
          habit: habit,
        ),
      ),
    );
  }

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TimeOfDay _time;
  late bool _isEnabled;

  // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  final Set<int> _selectedDays = {};

  final List<String> _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

  @override
  void initState() {
    super.initState();
    final r = widget.initialReminder;
    _titleController = TextEditingController(
      text: r?.title ?? 'Стань справжньою особистістю',
    );
    _descController = TextEditingController(text: r?.description ?? '');
    _time = r?.time ?? const TimeOfDay(hour: 8, minute: 0);
    _isEnabled = r?.isEnabled ?? true;

    if (r != null) {
      for (var day in r.daysOfWeek) {
        _selectedDays.add(day.type);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
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
                    'Готово',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: palette.isDark
                          ? Brightness.dark
                          : Brightness.light,
                      primaryColor: palette.primary,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime: DateTime(
                        0,
                        0,
                        0,
                        _time.hour,
                        _time.minute,
                      ),
                      onDateTimeChanged: (DateTime newTime) {
                        setState(() {
                          _time = TimeOfDay(
                            hour: newTime.hour,
                            minute: newTime.minute,
                          );
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() async {
    // Description fallback to Habit name if empty
    String finalDesc = _descController.text.trim();
    if (finalDesc.isEmpty) {
      finalDesc = widget.habit.name;
    }

    final reminderService = ReminderService();

    if (_isEnabled) {
      final allowed = await reminderService.requestAccessToSendNotifications();
      if (!allowed) {
        await DialogService().promptOpenNotificationSettings();
      }
    }

    final List<WeekDay> weekDays = [];
    final random = Random();

    for (int dayType in _selectedDays) {
      // Find existing ID or generate a new random one
      int reqId =
          widget.initialReminder?.daysOfWeek
              .firstWhere(
                (w) => w.type == dayType,
                orElse: () => WeekDay(
                  type: dayType,
                  userNotificationRequestId: random.nextInt(1000000),
                ),
              )
              .userNotificationRequestId ??
          random.nextInt(1000000);

      weekDays.add(WeekDay(type: dayType, userNotificationRequestId: reqId));
    }

    final reminder = HabitReminder(
      id: widget.initialReminder?.id,
      title: _titleController.text.trim(),
      description: finalDesc,
      time: _time,
      isEnabled: _isEnabled,
      daysOfWeek: weekDays,
    );

    // Cancel old notifications for days that were unchecked
    if (widget.initialReminder != null) {
      for (var oldDay in widget.initialReminder!.daysOfWeek) {
        if (!_selectedDays.contains(oldDay.type)) {
          await reminderService.cancelNotification(
            oldDay.userNotificationRequestId,
          );
        }
      }
    }

    // Schedule or Cancel according to isEnabled
    for (var wd in reminder.daysOfWeek) {
      await reminderService.addNotificationToDeviceAsync(reminder, wd);
    }

    if (mounted) {
      Navigator.pop(context, reminder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return Material(
      key: const Key('reminderSheetSurface'),
      color: palette.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                key: const Key('reminderSheetHandle'),
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
              'Нагадування',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              key: const Key('reminderTitleField'),
              controller: _titleController,
              style: TextStyle(color: palette.textPrimary),
              cursorColor: palette.primary,
              decoration: InputDecoration(
                labelText: 'Заголовок',
                labelStyle: TextStyle(color: palette.textMuted),
                prefixIcon: Icon(
                  Icons.local_offer_outlined,
                  color: palette.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              key: const Key('reminderDescriptionField'),
              controller: _descController,
              style: TextStyle(color: palette.textPrimary),
              cursorColor: palette.primary,
              decoration: InputDecoration(
                labelText: 'Опис',
                labelStyle: TextStyle(color: palette.textMuted),
                prefixIcon: Icon(
                  Icons.description_outlined,
                  color: palette.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              key: const Key('reminderTimeField'),
              onTap: _selectTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Час',
                  labelStyle: TextStyle(color: palette.textMuted),
                  prefixIcon: Icon(Icons.access_time, color: palette.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _time.format(context),
                  style: TextStyle(fontSize: 16, color: palette.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Switch(
                  key: const Key('reminderEnabledSwitch'),
                  value: _isEnabled,
                  onChanged: (val) => setState(() => _isEnabled = val),
                  activeTrackColor: palette.primary,
                  activeThumbColor: palette.onPrimary,
                ),
                Text(
                  'Увімкнути',
                  style: TextStyle(fontSize: 16, color: palette.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Days selection
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayType = index + 1; // 1 to 7
                final isSelected = _selectedDays.contains(dayType);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(dayType);
                      } else {
                        _selectedDays.add(dayType);
                      }
                    });
                  },
                  child: CircleAvatar(
                    key: Key('reminderDay$dayType'),
                    radius: 20,
                    backgroundColor: isSelected
                        ? palette.primary
                        : palette.primary.withValues(
                            alpha: palette.isDark ? 0.12 : 0.10,
                          ),
                    child: Text(
                      _dayLabels[index],
                      style: TextStyle(
                        color: isSelected ? palette.onPrimary : palette.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('reminderCancelButton'),
                    style: TextButton.styleFrom(
                      backgroundColor: palette.textPrimary.withValues(
                        alpha: palette.isDark ? 0.18 : 0.08,
                      ),
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(
                        color: palette.cardBorder.withValues(alpha: 0.65),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Скасувати',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('reminderSaveButton'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _save,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Зберегти',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
