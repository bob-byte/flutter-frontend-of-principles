import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/task_theme_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../l10n/schedule_strings.dart';
import '../../../models/schedule_reminder_offset.dart';
import '../../../viewmodels/schedule_draft.dart';
import '../../../widgets/tasks_glass.dart';
import 'reminder_picker_sheet.dart';
import 'repeat_picker_sheet.dart';
import 'schedule_format.dart';

Future<ScheduleDraft?> showScheduleBottomSheet(
  BuildContext context, {
  ScheduleDraft? initial,
  bool showRepeat = true,
  bool showDateDuration = true,
  bool showDuration = false,
}) {
  final palette = context.read<ThemeController>().palette;
  final draft =
      initial ??
      ScheduleDraft.defaults(
        showRepeat: showRepeat,
        showDateDuration: showDateDuration,
        showDuration: showDuration,
      );

  return showModalBottomSheet<ScheduleDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ChangeNotifierProvider<ScheduleDraft>.value(
        value: draft,
        child: ScheduleBottomSheet(palette: palette),
      );
    },
  );
}

class ScheduleBottomSheet extends StatelessWidget {
  const ScheduleBottomSheet({super.key, required this.palette});

  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    final strings = ScheduleStrings.of(context);
    final draft = context.watch<ScheduleDraft>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: TasksGlassPanel(
        palette: palette,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        strings.cancel,
                        style: TextStyle(color: palette.primary),
                      ),
                    ),
                    Expanded(
                      child: !draft.showDateDuration
                          ? Center(
                              child: Text(
                                strings.reminder,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : draft.showDuration
                          ? _TabSwitch(palette: palette, strings: strings)
                          : Center(
                              child: Text(
                                strings.date,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, draft),
                      child: Text(
                        strings.done,
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: !draft.showDateDuration
                      ? _TimeReminderOnly(palette: palette, strings: strings)
                      : draft.showDuration && draft.tab == ScheduleTab.duration
                      ? _DurationTab(palette: palette, strings: strings)
                      : _DateTab(palette: palette, strings: strings),
                ),
              ),
              TextButton(
                onPressed: () {
                  draft.clear();
                  Navigator.pop(context, draft);
                },
                child: Text(
                  strings.clear,
                  style: TextStyle(
                    color: palette.isDark
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFFC62828),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.softBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Seg(
              label: strings.date,
              selected: draft.tab == ScheduleTab.date,
              palette: palette,
              onTap: () => draft.setTab(ScheduleTab.date),
            ),
            _Seg(
              label: strings.duration,
              selected: draft.tab == ScheduleTab.duration,
              palette: palette,
              onTap: () => draft.setTab(ScheduleTab.duration),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TasksUiPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.onPrimary : palette.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TimeReminderOnly extends StatelessWidget {
  const _TimeReminderOnly({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final slots = draft.habitTimeSlots;
    return _SettingsCard(
      palette: palette,
      children: [
        for (var i = 0; i < slots.length; i++)
          _HabitTimeSlotBlock(
            palette: palette,
            strings: strings,
            index: i,
            slot: slots[i],
          ),
        _AddTimeRow(palette: palette, strings: strings),
        _ReminderRow(palette: palette, strings: strings),
      ],
    );
  }
}

class _HabitTimeSlotBlock extends StatelessWidget {
  const _HabitTimeSlotBlock({
    required this.palette,
    required this.strings,
    required this.index,
    required this.slot,
  });

  final TasksUiPalette palette;
  final ScheduleStrings strings;
  final int index;
  final HabitTimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final draft = context.read<ScheduleDraft>();
    final label = formatHabitTimeHHmm(slot.time);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          leading: Icon(Icons.access_time, color: palette.primary),
          title: Text(strings.time, style: TextStyle(color: palette.primary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: palette.primary)),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: palette.primary),
                onPressed: () => draft.removeTimeSlot(index),
              ),
            ],
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: slot.time,
            );
            if (picked != null) draft.setSlotTime(index, picked);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayChip(
                      label: strings.weekdayPills[d - 1],
                      selected: slot.weekdays.contains(d),
                      palette: palette,
                      onTap: () => draft.toggleSlotDay(index, d),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TasksUiPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? palette.primary
                : palette.cardBorder.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.onPrimary : palette.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _AddTimeRow extends StatelessWidget {
  const _AddTimeRow({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.read<ScheduleDraft>();
    return ListTile(
      dense: true,
      leading: Icon(Icons.add, color: palette.primary),
      title: Text(
        strings.addTime,
        style: TextStyle(color: palette.primary, fontWeight: FontWeight.w600),
      ),
      onTap: draft.addTimeSlot,
    );
  }
}

class _DateTab extends StatelessWidget {
  const _DateTab({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    return Column(
      children: [
        _MonthCalendar(palette: palette),
        const SizedBox(height: 12),
        _SettingsCard(
          palette: palette,
          children: [
            _TimeRow(palette: palette, strings: strings),
            _ReminderRow(palette: palette, strings: strings),
            if (draft.showRepeat)
              _RepeatRow(palette: palette, strings: strings),
          ],
        ),
      ],
    );
  }
}

class _DurationTab extends StatelessWidget {
  const _DurationTab({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final start = draft.dueDate ?? DateTime.now();
    final end = draft.endDate ?? start.add(const Duration(hours: 1));
    final durationText = formatDurationText(end.difference(start));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StartEndColumn(
                palette: palette,
                strings: strings,
                title: strings.start,
                date: start,
                subtitle: isSameDay(start, DateTime.now())
                    ? strings.today
                    : null,
                onTap: () => _pickDateTime(
                  context,
                  draft,
                  isStart: true,
                  initial: start,
                ),
              ),
            ),
            Expanded(
              child: _StartEndColumn(
                palette: palette,
                strings: strings,
                title: strings.end,
                date: end,
                subtitle: strings.durationLabel(durationText),
                onTap: () =>
                    _pickDateTime(context, draft, isStart: false, initial: end),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          palette: palette,
          children: [
            _AllDayRow(palette: palette, strings: strings),
            _ReminderRow(palette: palette, strings: strings),
            if (draft.showRepeat)
              _RepeatRow(palette: palette, strings: strings),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    ScheduleDraft draft, {
    required bool isStart,
    required DateTime initial,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    var result = DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
    if (!draft.allDay) {
      final tod = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (tod != null) {
        result = DateTime(
          date.year,
          date.month,
          date.day,
          tod.hour,
          tod.minute,
        );
      }
    }
    if (isStart) {
      draft.setStart(result);
    } else {
      draft.setEnd(result);
    }
  }
}

class _StartEndColumn extends StatelessWidget {
  const _StartEndColumn({
    required this.palette,
    required this.strings,
    required this.title,
    required this.date,
    required this.onTap,
    this.subtitle,
  });

  final TasksUiPalette palette;
  final ScheduleStrings strings;
  final String title;
  final DateTime date;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${date.day} ${monthShort(date.month)}, ${weekdayShort(date.weekday)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.palette});

  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final month = draft.calendarMonth;
    final selected = draft.dueDate;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday; // 1=Mon
    final today = dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                final prev = DateTime(month.year, month.month - 1, 1);
                draft.selectDate(
                  DateTime(
                    prev.year,
                    prev.month,
                    (selected?.day ?? 1).clamp(1, 28),
                  ),
                );
              },
              icon: Icon(Icons.chevron_left, color: palette.textMuted),
            ),
            Text(
              monthName(month.month),
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            IconButton(
              onPressed: () {
                final next = DateTime(month.year, month.month + 1, 1);
                draft.selectDate(
                  DateTime(
                    next.year,
                    next.month,
                    (selected?.day ?? 1).clamp(1, 28),
                  ),
                );
              },
              icon: Icon(Icons.chevron_right, color: palette.textMuted),
            ),
          ],
        ),
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ((startWeekday - 1) + daysInMonth),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < startWeekday - 1) return const SizedBox.shrink();
            final day = index - (startWeekday - 1) + 1;
            final date = DateTime(month.year, month.month, day);
            final isSelected = selected != null && isSameDay(selected, date);
            final isToday = isSameDay(today, date);
            return GestureDetector(
              onTap: () => draft.selectDate(date),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? palette.primary
                      : isToday
                      ? palette.textPrimary
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? palette.onPrimary
                        : isToday
                        ? (palette.isDark ? Colors.black : Colors.white)
                        : palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.palette, required this.children});

  final TasksUiPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                color: palette.cardBorder.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final active = draft.hasTime && !draft.allDay;
    final label = active && draft.dueDate != null
        ? '${draft.dueDate!.hour.toString().padLeft(2, '0')}:${draft.dueDate!.minute.toString().padLeft(2, '0')}'
        : null;

    return ListTile(
      dense: true,
      leading: Icon(
        Icons.access_time,
        color: active ? palette.primary : palette.textMuted,
      ),
      title: Text(
        strings.time,
        style: TextStyle(color: active ? palette.primary : palette.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Text(label, style: TextStyle(color: palette.primary)),
          if (active)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: palette.primary),
              onPressed: draft.clearTime,
            ),
        ],
      ),
      onTap: () async {
        final initial = draft.hasTime && draft.dueDate != null
            ? TimeOfDay.fromDateTime(draft.dueDate!)
            : const TimeOfDay(hour: 9, minute: 0);
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) draft.setTime(picked);
      },
    );
  }
}

class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    return SwitchListTile.adaptive(
      dense: true,
      title: Text(strings.allDay, style: TextStyle(color: palette.textPrimary)),
      value: draft.allDay,
      activeThumbColor: palette.primary,
      onChanged: draft.setAllDay,
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final active = draft.reminders.isNotEmpty;
    final label = active
        ? _reminderSummary(strings, draft.reminders)
        : strings.none;

    return ListTile(
      dense: true,
      leading: Icon(
        Icons.alarm,
        color: active ? palette.primary : palette.textMuted,
      ),
      title: Text(
        strings.reminder,
        style: TextStyle(color: active ? palette.primary : palette.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? palette.primary : palette.textMuted,
            ),
          ),
          if (active)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: palette.primary),
              onPressed: () => draft.setReminders(const []),
            )
          else
            Icon(Icons.unfold_more, color: palette.textMuted, size: 18),
        ],
      ),
      onTap: () async {
        final result = await showReminderPickerSheet(
          context,
          palette: palette,
          selected: draft.reminders,
          constantReminder: draft.constantReminder,
          anchor: draft.dueDate,
        );
        if (result != null) {
          draft.setReminders(result.offsets);
          draft.setConstantReminder(result.constantReminder);
        }
      },
    );
  }
}

class _RepeatRow extends StatelessWidget {
  const _RepeatRow({required this.palette, required this.strings});

  final TasksUiPalette palette;
  final ScheduleStrings strings;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<ScheduleDraft>();
    final active = !draft.repeat.isNone;
    final label = formatRepeatLabel(strings, draft.repeat, draft.dueDate);

    return ListTile(
      dense: true,
      leading: Icon(
        Icons.repeat,
        color: active ? palette.primary : palette.textMuted,
      ),
      title: Text(
        strings.repeat,
        style: TextStyle(color: active ? palette.primary : palette.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? palette.primary : palette.textMuted,
            ),
          ),
          Icon(Icons.unfold_more, color: palette.textMuted, size: 18),
        ],
      ),
      onTap: () async {
        final result = await showRepeatPickerSheet(
          context,
          palette: palette,
          selected: draft.repeat,
          selectedDay: draft.dueDate ?? DateTime.now(),
        );
        if (result != null) draft.setRepeat(result);
      },
    );
  }
}

String _reminderSummary(
  ScheduleStrings s,
  List<ScheduleReminderOffset> offsets,
) {
  if (offsets.isEmpty) return s.none;
  if (offsets.length == 1) {
    return formatOffsetLabel(s, offsets.first.offsetMinutes);
  }
  return '${offsets.length}';
}
