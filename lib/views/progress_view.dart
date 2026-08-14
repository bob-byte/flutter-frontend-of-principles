import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../models/habit_record.dart';
import '../models/habit.dart';
import '../viewmodels/progress_viewmodel.dart';
import 'edit_habit_view.dart';
import '../app/app.dart';
import '../services/dialog_service.dart';
import 'widgets/global_reminder_sheet.dart';

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});

  static const routeName = '/progress';

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressViewModel>(
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC), // Світлий фон як на дизайні
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, vm),
                const SizedBox(height: 16),
                _buildDateCarousel(context, vm),
                const SizedBox(height: 16),
                _buildSummaryBanner(context, vm),
                const SizedBox(height: 16),
                Expanded(child: _buildHabitsList(context, vm)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF3374FF),
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: () async {
              await EditHabitView.show(context);
              if (context.mounted) {
                context.read<ProgressViewModel>().load();
              }
            },
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ProgressViewModel vm) {
    final today = DateTime.now();
    final isTodaySelected = vm.selectedDate.year == today.year && 
                            vm.selectedDate.month == today.month && 
                            vm.selectedDate.day == today.day;
    
    // Формат "Сьогодні, Пт" або "П'ятниця, 4 Жовтня"
    final dateFmt = DateFormat(isTodaySelected ? "'Сьогодні', E" : "d MMMM, E", 'uk');
    final dateTitle = dateFmt.format(vm.selectedDate);

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateTitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Мої звички',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          Row(
            children: [
              // Стрік
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Показує кількість днів поспіль, коли ви відкривали додаток і виконували звички. Якщо пропустити хоча б один день — серія обнуляється.',
                        style: TextStyle(color: Colors.black87),
                      ),
                      backgroundColor: const Color(0xFF7EBAFF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      action: SnackBarAction(
                        label: 'OK',
                        textColor: Colors.white,
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${vm.currentStreak}',
                        style: const TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Дзвіночок
              GestureDetector(
                onTap: () {
                  GlobalReminderBottomSheet.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F1FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none, color: Color(0xFF3374FF), size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Архів
              GestureDetector(
                onTap: () {
                  DialogService().showCustomSheet(
                    variant: BottomSheetType.archive,
                  ).then((_) {
                    context.read<ProgressViewModel>().load();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.archive_outlined, color: Colors.grey, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateCarousel(BuildContext context, ProgressViewModel vm) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: vm.dates.length,
        itemBuilder: (context, index) {
          final date = vm.dates[index];
          final isSelected = date.year == vm.selectedDate.year && 
                             date.month == vm.selectedDate.month && 
                             date.day == vm.selectedDate.day;
          
          final weekdayStr = DateFormat('E', 'uk').format(date).toUpperCase();
          final dayStr = '${date.day}';

          return GestureDetector(
            onTap: () => vm.selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3374FF) : Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF3374FF).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayStr,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Маленька смужка прогресу знизу (фейкова або реальна, для дизайну покажемо як 1 сегмент)
                  Container(
                    width: 24,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1, 
                          child: Container(decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFF3374FF), borderRadius: BorderRadius.circular(2)))
                        ),
                        Expanded(flex: 1, child: Container()),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBanner(BuildContext context, ProgressViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Color(0xFF3374FF)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Виконано сьогодні',
                style: TextStyle(color: Color(0xFF3374FF), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Text(
              '${vm.completedHabitsCount}/${vm.totalHabitsCount}',
              style: const TextStyle(color: Color(0xFF3374FF), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsList(BuildContext context, ProgressViewModel vm) {
    if (vm.groupedHabits.isEmpty) {
      return const Center(child: Text("Немає звичок. Натисніть + щоб додати."));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
      itemCount: vm.groupedHabits.keys.length,
      itemBuilder: (context, index) {
        final timeKey = vm.groupedHabits.keys.elementAt(index);
        final habitsInGroup = vm.groupedHabits[timeKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time separator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(timeKey, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),
            ),
            // Habit Cards
            ...habitsInGroup.map((habit) => _buildHabitCard(context, habit, vm)),
          ],
        );
      },
    );
  }

  Widget _buildHabitCard(BuildContext context, Habit habit, ProgressViewModel vm) {
    final status = vm.getStatusForHabitAndDate(habit.id ?? 0, vm.selectedDate);
    final isCompleted = status == HabitStatus.completed;
    final weeklyProgress = vm.getWeeklyProgress(habit, vm.selectedDate);
    final percentStr = (weeklyProgress * 100).toInt().toString();

    return GestureDetector(
      onLongPress: () => _showHabitMenu(context, habit, vm),
      onTap: () {
        Navigator.pushNamed(
          context, 
          '/habit-detail', 
          arguments: habit.id,
        ).then((_) => vm.load(silent: true));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isCompleted ? Border.all(color: Colors.green.shade200, width: 2) : Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Left Icon / Progress Indicator
            CircularPercentIndicator(
              radius: 24.0,
              lineWidth: 4.0,
              percent: weeklyProgress,
              center: Text(
                '$percentStr%', 
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isCompleted ? Colors.green : const Color(0xFF3374FF),
                ),
              ),
              progressColor: isCompleted ? Colors.green : const Color(0xFF3374FF),
              backgroundColor: const Color(0xFFE8F1FF),
            ),
            const SizedBox(width: 16),
            
            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: isCompleted ? Colors.grey : Colors.black87,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (habit.reminderTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(habit.reminderTime!),
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Right Checkbox
            GestureDetector(
              onTap: () => vm.toggleHabitStatus(habit.id ?? 0, vm.selectedDate),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.green : Colors.grey.shade100,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHabitMenu(BuildContext context, Habit habit, ProgressViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Habit Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 16.0,
                      lineWidth: 3.0,
                      percent: vm.getWeeklyProgress(habit, vm.selectedDate),
                      center: Text("${(vm.getWeeklyProgress(habit, vm.selectedDate) * 100).toInt()}%", style: const TextStyle(fontSize: 8)),
                      progressColor: Colors.blue,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        habit.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Menu Options
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Змінити'),
                      trailing: const Icon(Icons.edit, color: Colors.black87),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await EditHabitView.show(context, habit: habit);
                        if (context.mounted) {
                          context.read<ProgressViewModel>().load();
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Архівувати'),
                      trailing: const Icon(Icons.archive, color: Colors.black87),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmArchive(context, habit, vm);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Видалити', style: TextStyle(color: Colors.red)),
                      trailing: const Icon(Icons.delete, color: Colors.black87),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDelete(context, habit, vm);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmArchive(BuildContext context, Habit habit, ProgressViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('Перемістити звичку в архів?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        content: const Text(
          'Ця дія перемістить звичку в архів. Ви зможете відновити роботу над нею пізніше.',
          textAlign: TextAlign.center,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ні', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(color: Colors.grey),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.archiveHabit(habit);
            },
            child: const Text('Так', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Habit habit, ProgressViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('Видалити звичку?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        content: const Text(
          'Звичку буде видалено назавжди. Ця дія не може бути скасована.',
          textAlign: TextAlign.center,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ні', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(color: Colors.grey),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.deleteHabit(habit);
            },
            child: const Text('Так', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
