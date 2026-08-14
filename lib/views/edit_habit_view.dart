import 'package:flutter/material.dart';
import 'package:super_tooltip/super_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../viewmodels/edit_habit_viewmodel.dart';
import '../models/frequency_config.dart';
import '../models/user_goal.dart';
import 'widgets/reminder_bottom_sheet.dart';
import '../models/habit.dart';

class EditHabitView extends StatelessWidget {
  const EditHabitView({super.key});

  static Future<void> show(BuildContext context, {Habit? habit}) {
    context.read<EditHabitViewModel>().init(habit);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
        child: const EditHabitView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.blue,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Звичка', 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Consumer<EditHabitViewModel>(
                        builder: (context, vm, child) {
                          return TextButton(
                            onPressed: vm.isSaving ? null : () async {
                              final success = await vm.saveHabit();
                              if (success && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: vm.isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('ЗБЕРЕГТИ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ],
                  ),
                  const TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: [
                      Tab(text: 'Дані'),
                      Tab(text: 'Як утримувати'),
                    ],
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _DataTab(),
                  _HowToKeepTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataTab extends StatefulWidget {
  const _DataTab();

  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  final _tooltipController = SuperTooltipController();

  @override
  void dispose() {
    _tooltipController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditHabitViewModel>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Name Field
          TextField(
            decoration: InputDecoration(
              labelText: 'Назва',
              prefixIcon: const Icon(Icons.local_fire_department),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: SuperTooltip(
                controller: _tooltipController,
                style: const TooltipStyle(
                  backgroundColor: Color(0xFF7EBAFF),
                  hasShadow: false,
                ),
                positionConfig: const PositionConfiguration(
                  preferredDirection: TooltipDirection.up,
                ),
                content: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Вкажіть назву звички та час або місце її виконання. Це збільшить ймовірність її дотримання. Приклад: я молюсь, як тільки прокинусь.',
                          style: TextStyle(color: Colors.black87, fontSize: 13),
                          softWrap: true,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        onPressed: () => _tooltipController.hideTooltip(),
                        child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.info, color: Colors.grey),
                  onPressed: () => _tooltipController.showTooltip(),
                ),
              ),
            ),
            onChanged: (val) => vm.habitName = val,
            controller: TextEditingController(text: vm.habitName)..selection = TextSelection.collapsed(offset: vm.habitName.length),
          ),
          const SizedBox(height: 16),
          
          // Goal
          InkWell(
            onTap: () => vm.requestGoalSelection(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes),
                  const SizedBox(width: 12),
                  Text(
                    vm.targetGoal.isEmpty ? 'Ціль' : vm.targetGoal, 
                    style: TextStyle(fontSize: 16, color: vm.targetGoal.isEmpty ? Colors.black87 : Colors.blue.shade700, fontWeight: vm.targetGoal.isEmpty ? FontWeight.normal : FontWeight.bold)
                  ),
                  const Spacer(),
                  const Icon(Icons.more_horiz),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Segmented Control (Flexible / Strict)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vm.isFlexible ? Colors.blue : Colors.grey.shade200,
                    foregroundColor: vm.isFlexible ? Colors.white : Colors.black87,
                  ),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Гнучка'),
                  onPressed: () => vm.setFlexible(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !vm.isFlexible ? Colors.blue : Colors.grey.shade200,
                    foregroundColor: !vm.isFlexible ? Colors.white : Colors.black87,
                  ),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Без винятків'),
                  onPressed: () => vm.setFlexible(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Frequency
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Частота', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => vm.requestFrequencyConfig(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.loop),
                  const SizedBox(width: 12),
                  Text(vm.frequency.displayString, style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  const Icon(Icons.more_horiz),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reminder
          InkWell(
            onTap: () async {
              final habitForReminder = Habit(
                name: vm.habitName,
                frequency: vm.frequency,
              ); // Mock habit just to pass name
              final reminder = await ReminderBottomSheet.show(
                context, 
                habitForReminder, 
                initialReminder: vm.reminders.isNotEmpty ? vm.reminders.first : null
              );
              if (reminder != null) {
                vm.setReminder(reminder);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none),
                  const SizedBox(width: 12),
                  Text(
                    vm.reminders.isNotEmpty ? '${vm.reminders.first.time.format(context)}' : 'Нагадування',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  const Icon(Icons.more_horiz),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToKeepTab extends StatelessWidget {
  const _HowToKeepTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditHabitViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Notes
          TextField(
            decoration: InputDecoration(
              labelText: 'Нотатки',
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: null,
            onChanged: (val) => vm.notes = val,
            controller: TextEditingController(text: vm.notes)..selection = TextSelection.collapsed(offset: vm.notes.length),
          ),
          const SizedBox(height: 24),
          
          // Difficulty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart),
                const SizedBox(width: 16),
                const Text('Складність (1 - 10)'),
                const Spacer(),
                Text('${vm.difficulty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: vm.decrementDifficulty,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: vm.incrementDifficulty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
