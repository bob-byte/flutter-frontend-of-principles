import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/task_theme_palette.dart';
import '../../../l10n/schedule_strings.dart';
import '../../../models/task_repeat_config.dart';
import 'schedule_format.dart';

Future<TaskRepeatConfig?> showCustomRepeatSheet(
  BuildContext context, {
  required TasksUiPalette palette,
  required TaskRepeatConfig initial,
  required DateTime selectedDay,
}) {
  return showModalBottomSheet<TaskRepeatConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CustomRepeatSheet(
      palette: palette,
      initial: initial,
      selectedDay: selectedDay,
    ),
  );
}

class _CustomRepeatSheet extends StatefulWidget {
  const _CustomRepeatSheet({
    required this.palette,
    required this.initial,
    required this.selectedDay,
  });

  final TasksUiPalette palette;
  final TaskRepeatConfig initial;
  final DateTime selectedDay;

  @override
  State<_CustomRepeatSheet> createState() => _CustomRepeatSheetState();
}

class _CustomRepeatSheetState extends State<_CustomRepeatSheet> {
  late TaskRepeatAnchor _anchor;
  late int _interval;
  late TaskRepeatUnit _unit;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    _anchor = widget.initial.anchor;
    _interval = widget.initial.interval.clamp(1, 99);
    _unit = widget.initial.preset == TaskRepeatPreset.custom
        ? widget.initial.unit
        : TaskRepeatUnit.week;
    _weekdays = widget.initial.weekdays.isEmpty
        ? {widget.selectedDay.weekday}
        : widget.initial.weekdays.toSet();
  }

  String get _summary {
    final strings = ScheduleStrings.of(context);
    switch (_unit) {
      case TaskRepeatUnit.day:
        return '${strings.every} $_interval ${strings.dayUnit.toLowerCase()}';
      case TaskRepeatUnit.week:
        final days = (_weekdays.toList()..sort())
            .map(weekdayShort)
            .join(', ');
        return '${strings.every} $_interval ${strings.weekUnit.toLowerCase()} ($days)';
      case TaskRepeatUnit.month:
        return '${strings.every} $_interval ${strings.monthUnit.toLowerCase()}';
      case TaskRepeatUnit.year:
        return '${strings.every} $_interval ${strings.yearUnit.toLowerCase()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ScheduleStrings.of(context);
    final palette = widget.palette;
    return Material(
      color: palette.pageBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      strings.cancel,
                      style: TextStyle(color: palette.primary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      strings.customRepeat,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        TaskRepeatConfig(
                          preset: TaskRepeatPreset.custom,
                          interval: _interval,
                          unit: _unit,
                          weekdays: _weekdays.toList()..sort(),
                          anchor: _anchor,
                        ),
                      );
                    },
                    child: Text(
                      strings.done,
                      style: TextStyle(color: palette.primary),
                    ),
                  ),
                ],
              ),
              _Card(
                palette: palette,
                child: ListTile(
                  title: Text(
                    strings.repeatType,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<TaskRepeatAnchor>(
                      value: _anchor,
                      dropdownColor: palette.cardBg,
                      style: TextStyle(color: palette.textPrimary),
                      items: [
                        DropdownMenuItem(
                          value: TaskRepeatAnchor.dueDates,
                          child: Text(strings.byDueDates),
                        ),
                        DropdownMenuItem(
                          value: TaskRepeatAnchor.completion,
                          child: Text(strings.byCompletion),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _anchor = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.frequency,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Card(
                palette: palette,
                child: SizedBox(
                  height: 140,
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            strings.every,
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 32,
                          scrollController: FixedExtentScrollController(
                            initialItem: _interval - 1,
                          ),
                          onSelectedItemChanged: (i) =>
                              setState(() => _interval = i + 1),
                          children: [
                            for (var i = 1; i <= 30; i++)
                              Center(
                                child: Text(
                                  '$i',
                                  style: TextStyle(color: palette.textPrimary),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 32,
                          scrollController: FixedExtentScrollController(
                            initialItem: TaskRepeatUnit.values.indexOf(_unit),
                          ),
                          onSelectedItemChanged: (i) => setState(
                            () => _unit = TaskRepeatUnit.values[i],
                          ),
                          children: [
                            Center(
                              child: Text(
                                strings.dayUnit,
                                style: TextStyle(color: palette.textPrimary),
                              ),
                            ),
                            Center(
                              child: Text(
                                strings.weekUnit,
                                style: TextStyle(color: palette.textPrimary),
                              ),
                            ),
                            Center(
                              child: Text(
                                strings.monthUnit,
                                style: TextStyle(color: palette.textPrimary),
                              ),
                            ),
                            Center(
                              child: Text(
                                strings.yearUnit,
                                style: TextStyle(color: palette.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _summary,
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
              if (_unit == TaskRepeatUnit.week) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    strings.week,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      ChoiceChip(
                        label: Text(weekdayPill(d)),
                        selected: _weekdays.contains(d),
                        selectedColor: palette.primary,
                        labelStyle: TextStyle(
                          color: _weekdays.contains(d)
                              ? palette.onPrimary
                              : palette.textPrimary,
                        ),
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              _weekdays.add(d);
                            } else if (_weekdays.length > 1) {
                              _weekdays.remove(d);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.palette, required this.child});

  final TasksUiPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.softBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
