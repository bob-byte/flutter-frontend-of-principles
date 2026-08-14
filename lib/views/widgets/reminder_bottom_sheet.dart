import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/habit_reminder.dart';
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

  static Future<HabitReminder?> show(BuildContext context, Habit habit, {HabitReminder? initialReminder}) {
    return showModalBottomSheet<HabitReminder>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
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
    _titleController = TextEditingController(text: r?.title ?? 'Стань справжньою особистістю');
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
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(0, 0, 0, _time.hour, _time.minute),
                    onDateTimeChanged: (DateTime newTime) {
                      setState(() {
                        _time = TimeOfDay(hour: newTime.hour, minute: newTime.minute);
                      });
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

  void _save() async {
    // Description fallback to Habit name if empty
    String finalDesc = _descController.text.trim();
    if (finalDesc.isEmpty) {
      finalDesc = widget.habit.name;
    }

    final reminderService = ReminderService();
    await reminderService.requestPermissions();

    final List<WeekDay> weekDays = [];
    final random = Random();

    for (int dayType in _selectedDays) {
      // Find existing ID or generate a new random one
      int reqId = widget.initialReminder?.daysOfWeek
              .firstWhere((w) => w.type == dayType, orElse: () => WeekDay(type: dayType, userNotificationRequestId: random.nextInt(1000000)))
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
          await reminderService.cancelNotification(oldDay.userNotificationRequestId);
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
    return SingleChildScrollView(
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Нагадування',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Заголовок',
              prefixIcon: const Icon(Icons.local_offer_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Опис',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: _selectTime,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Час',
                prefixIcon: const Icon(Icons.access_time),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_time.format(context), style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Switch(
                value: _isEnabled,
                onChanged: (val) => setState(() => _isEnabled = val),
                activeColor: Colors.blue,
              ),
              const Text('Увімкнути', style: TextStyle(fontSize: 16)),
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
                  radius: 20,
                  backgroundColor: isSelected ? Colors.blue : Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    _dayLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.blue,
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
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel, size: 18),
                      SizedBox(width: 4),
                      Text('Скасувати', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _save,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18),
                      SizedBox(width: 4),
                      Text('Зберегти', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
