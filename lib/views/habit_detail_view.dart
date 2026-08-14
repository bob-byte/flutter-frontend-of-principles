import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../viewmodels/habit_detail_viewmodel.dart';
import '../models/habit.dart'; // FrequencyConfig logic
import 'edit_habit_view.dart';

class HabitDetailView extends StatefulWidget {
  const HabitDetailView({super.key});

  static const routeName = '/habit-detail';

  @override
  State<HabitDetailView> createState() => _HabitDetailViewState();
}

class _HabitDetailViewState extends State<HabitDetailView> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final habitId = arg is int ? arg : null;
    context.read<HabitDetailViewModel>().load(localHabitId: habitId);
  }

  void _confirmArchive(BuildContext context, HabitDetailViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('Перемістити звичку в архів?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        content: const Text('Ця дія перемістить звичку в архів. Ви зможете відновити роботу над нею пізніше.', textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ні', style: TextStyle(color: Colors.blue, fontSize: 16))),
          const SizedBox(height: 24, child: VerticalDivider(color: Colors.grey)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await vm.toggleArchived();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Так', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, HabitDetailViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('Видалити звичку?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        content: const Text('Звичку буде видалено назавжди. Ця дія не може бути скасована.', textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ні', style: TextStyle(color: Colors.blue, fontSize: 16))),
          const SizedBox(height: 24, child: VerticalDivider(color: Colors.grey)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await vm.deleteHabit();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Так', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HabitDetailViewModel>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(vm.habit?.name ?? 'Деталі'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: vm.habit == null ? null : () => _confirmArchive(context, vm),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: vm.habit == null ? null : () => _confirmDelete(context, vm),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: vm.habit == null
            ? null
            : () async {
                await EditHabitView.show(context, habit: vm.habit);
                if (context.mounted && vm.habit?.id != null) {
                  vm.load(localHabitId: vm.habit!.id);
                }
              },
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: vm.isLoading || vm.habit == null
          ? const SizedBox.shrink() // Замість спінера показуємо пустий екран на кілька мілісекунд
          : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                vm.habit!.frequency.displayString.isEmpty ? 'Кожного дня' : vm.habit!.frequency.displayString,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Overall progress
                      const Text('Загальний прогрес', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${(vm.completionRate * 100).round()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: vm.completionRate,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.blue,
                              minHeight: 4,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Кількість виконань: ${vm.completedDays}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Найдовша серія: ${vm.longestStreak}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Top 5 Streaks Chart
                      Row(
                        children: [
                          const Text('Топ-5 найтриваліших серій', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.info, size: 20, color: Colors.black.withValues(alpha: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: _buildTop5StreaksChart(vm.topFiveStreaks),
                      ),
                      const SizedBox(height: 32),

                      // Stability Chart (Line chart over last 30 completions)
                      Row(
                        children: [
                          const Text('Стабільність', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.info, size: 20, color: Colors.black.withValues(alpha: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: _buildStabilityChart(vm.stabilitySeries),
                      ),
                      const SizedBox(height: 32),

                      // Weekdays Chart
                      Row(
                        children: [
                          const Text('Звичка за днями тижня', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.info, size: 20, color: Colors.black.withValues(alpha: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: _buildWeekdaysChart(vm.weekDayExecution),
                      ),
                      const SizedBox(height: 32),

                      // Calendar
                      Row(
                        children: [
                          const Text('Календар', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.info, size: 20, color: Colors.black.withValues(alpha: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCalendar(context, vm),
                      const SizedBox(height: 80), // Fab padding
                    ],
                  ),
                ),
    );
  }

  Widget _buildTop5StreaksChart(List<StreakStat> streaks) {
    if (streaks.isEmpty) {
      // Mock empty state to look like screenshot
      streaks = List.generate(5, (_) => StreakStat(start: DateTime.now(), end: DateTime.now(), days: 0));
    }
    
    // Pad to 5 if needed for visual consistency
    final displayStreaks = List<StreakStat>.from(streaks);
    while (displayStreaks.length < 5) {
      displayStreaks.add(StreakStat(start: DateTime.now(), end: DateTime.now(), days: 0));
    }

    double maxY = displayStreaks.map((s) => s.days).reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY < 30) maxY = 30; // To match the screenshot which shows up to 30

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= displayStreaks.length) return const SizedBox.shrink();
                final stat = displayStreaks[index];
                if (stat.days == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('0', style: TextStyle(fontSize: 12)));
                // You can add start/end date formatting here if requested, but screenshot shows 0s when empty
                return const Padding(padding: EdgeInsets.only(top: 8), child: Text(''));
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Кількість виконань', style: TextStyle(fontSize: 12)),
            axisNameSize: 20,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value % 5 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 12, color: Colors.black54));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayStreaks.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: displayStreaks[index].days.toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStabilityChart(List<double> stability) {
    if (stability.isEmpty) {
      stability = List.generate(10, (_) => 0.0);
    }
    
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                // Example: '9 січ', rotated
                if (value.toInt() % 2 != 0) return const SizedBox.shrink();
                return Transform.translate(
                  offset: const Offset(0, 10),
                  child: Transform.rotate(
                    angle: -0.5,
                    child: const Text('9 січ', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.black54));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(stability.length, (index) => FlSpot(index.toDouble(), stability[index])),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysChart(List<int> weekdays) {
    double maxY = weekdays.isEmpty ? 10 : weekdays.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) maxY = 10;
    
    final labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index > 6) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(labels[index], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Кількість виконань', style: TextStyle(fontSize: 12)),
            axisNameSize: 20,
            sideTitles: SideTitles(showTitles: false), // Hidden on this chart usually, or just leave it
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: weekdays[index].toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, HabitDetailViewModel vm) {
    final now = DateTime.now();
    final year = vm.currentMonth.year;
    final month = vm.currentMonth.month;
    final monthName = DateFormat('MMMM', 'uk').format(vm.currentMonth);
    
    // First day of month
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    
    // weekday is 1=Mon, 7=Sun. We want 0=Mon, 6=Sun
    final firstDayIndex = firstDay.weekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => vm.changeMonth(-1)),
                Column(
                  children: [
                    Text(year.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(monthName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => vm.changeMonth(1)),
              ],
            ),
          ),
          // Weekdays row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'НД']
                  .map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)))
                  .toList(),
            ),
          ),
          // Grid
          GridView.builder(
            padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 rows * 7 cols
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayIndex || index >= firstDayIndex + daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = index - firstDayIndex + 1;
              final date = DateTime(year, month, day);
              
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              final isCompleted = vm.completedCalendarDays.contains(date);

              return Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: isToday ? const Border(bottom: BorderSide(color: Colors.black, width: 2)) : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isCompleted)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        day.toString(),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted ? Colors.green.shade800 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
