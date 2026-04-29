import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../viewmodels/habit_detail_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(
        title: Consumer<HabitDetailViewModel>(
          builder: (context, vm, child) => Text(vm.habit?.name ?? l10n.habitDetailsFallbackTitle),
        ),
        actions: [
          Consumer<HabitDetailViewModel>(
            builder: (context, vm, child) => IconButton(
              tooltip: vm.habit?.isArchived == true ? l10n.unarchiveTooltip : l10n.archiveTooltip,
              onPressed: vm.habit == null ? null : vm.toggleArchived,
              icon: Icon(vm.habit?.isArchived == true ? Icons.unarchive : Icons.archive_outlined),
            ),
          ),
          Consumer<HabitDetailViewModel>(
            builder: (context, vm, child) => IconButton(
              tooltip: l10n.deleteTooltip,
              onPressed: vm.habit == null
                  ? null
                  : () async {
                      await vm.deleteHabit();
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                    },
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
      body: Consumer<HabitDetailViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.habit == null) {
            return Center(child: Text(l10n.noHabitSelected));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (vm.habit!.frequencyText.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(vm.habit!.frequencyText),
                    ),
                  if (vm.habit!.reminderText.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.alarm, size: 18),
                      label: Text(vm.habit!.reminderText),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.overallProgress, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${(vm.completionRate * 100).round()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: vm.completionRate),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.executionCount(vm.completedDays)),
                          Text(l10n.longestStreak(vm.longestStreak)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.topFiveStreaks, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (vm.topFiveStreaks.isEmpty)
                Text(l10n.noStreaksYet)
              else
                ...vm.topFiveStreaks.map(
                  (s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text(l10n.streakDays(s.days)),
                    subtitle: Text(
                      '${DateFormat.yMd(localeName).format(s.start)} - ${DateFormat.yMd(localeName).format(s.end)}',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(l10n.stabilityTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: vm.stabilitySeries.isEmpty
                    ? Center(child: Text(l10n.noStabilityData))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: vm.stabilitySeries
                            .map(
                              (value) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1),
                                  child: Container(
                                    height: value.clamp(2, 100),
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 12),
              Text(l10n.habitByWeekdays, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildWeekdayBars(context, vm.weekDayExecution, l10n),
              const SizedBox(height: 12),
              Text(l10n.calendarTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _CalendarHeatmap(completedDays: vm.completedCalendarDays),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildWeekdayBars(BuildContext context, List<int> data, AppLocalizations l10n) {
    final dayNames = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final max = data.fold<int>(1, (p, e) => e > p ? e : p);
    return List<Widget>.generate(dayNames.length, (index) {
      final count = data[index];
      final ratio = count / max;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 40, child: Text(dayNames[index])),
            Expanded(
              child: LinearProgressIndicator(value: ratio),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Text('$count')),
          ],
        ),
      );
    });
  }
}

class _CalendarHeatmap extends StatelessWidget {
  const _CalendarHeatmap({required this.completedDays});

  final Set<DateTime> completedDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return GridView.builder(
      itemCount: daysInMonth,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final day = DateTime(start.year, start.month, index + 1);
        final normalized = DateTime(day.year, day.month, day.day);
        final done = completedDays.contains(normalized);
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: done ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}
