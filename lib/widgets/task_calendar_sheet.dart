import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_helpers.dart';
import '../l10n/task_strings.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'tasks_glass.dart';

Future<DateTime?> showTaskCalendarSheet(
  BuildContext context, {
  required DateTime initialDay,
  required Set<DateTime> daysWithTasks,
}) {
  final vm = context.read<TasksViewModel>();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Theme(
      data: vm.themeData,
      child: _TaskCalendarSheet(
        initialDay: dateOnly(initialDay),
        daysWithTasks: {
          for (final d in daysWithTasks) dateOnly(d),
        },
      ),
    ),
  );
}

class _TaskCalendarSheet extends StatefulWidget {
  const _TaskCalendarSheet({
    required this.initialDay,
    required this.daysWithTasks,
  });

  final DateTime initialDay;
  final Set<DateTime> daysWithTasks;

  @override
  State<_TaskCalendarSheet> createState() => _TaskCalendarSheetState();
}

class _TaskCalendarSheetState extends State<_TaskCalendarSheet> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
    _visibleMonth = DateTime(widget.initialDay.year, widget.initialDay.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    final palette = context.watch<TasksViewModel>().palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = MaterialLocalizations.of(context).formatMonthYear(
      _visibleMonth,
    );

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    // Monday-based grid (Ukrainian week).
    final startOffset = (firstOfMonth.weekday + 6) % 7;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final cellCount = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    final weekdayLabels = locale.toLowerCase().startsWith('uk')
        ? const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return TasksGlassSheet(
      palette: palette,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    strings.taskMenuCalendar,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shiftMonth(-1),
                    icon: Icon(Icons.chevron_left, color: palette.textPrimary),
                  ),
                  Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shiftMonth(1),
                    icon: Icon(Icons.chevron_right, color: palette.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final label in weekdayLabels)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = (constraints.maxWidth - 6 * 4) / 7;
                  final cellHeight = cellWidth.clamp(36.0, 48.0);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cellCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      mainAxisExtent: cellHeight,
                    ),
                    itemBuilder: (context, index) {
                      final dayNumber = index - startOffset + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const SizedBox.shrink();
                      }

                      final day = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        dayNumber,
                      );
                      final selected = isSameDay(day, _selectedDay);
                      final isToday = isSameDay(day, DateTime.now());
                      final hasTasks = widget.daysWithTasks.contains(day);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context, day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient:
                                  selected ? palette.primaryGradient : null,
                              color: selected
                                  ? null
                                  : (isToday
                                      ? palette.primary.withValues(alpha: 0.12)
                                      : null),
                              border: !selected && isToday
                                  ? Border.all(
                                      color: palette.primary
                                          .withValues(alpha: 0.45),
                                    )
                                  : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? palette.onPrimary
                                        : palette.textPrimary,
                                  ),
                                ),
                                if (hasTasks)
                                  Positioned(
                                    bottom: 5,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected
                                            ? palette.onPrimary
                                            : palette.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
