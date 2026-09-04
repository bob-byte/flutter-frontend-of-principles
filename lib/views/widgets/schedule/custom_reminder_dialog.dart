import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/task_theme_palette.dart';
import '../../../l10n/schedule_strings.dart';
import 'schedule_format.dart';

Future<int?> showCustomReminderDialog(
  BuildContext context, {
  required TasksUiPalette palette,
  DateTime? anchor,
  int initialDays = 0,
  int initialHours = 0,
  int initialMinutes = 15,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _CustomReminderDialog(
      palette: palette,
      strings: ScheduleStrings.of(context),
      anchor: anchor ?? DateTime.now(),
      initialDays: initialDays,
      initialHours: initialHours,
      initialMinutes: initialMinutes,
    ),
  );
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({
    required this.palette,
    required this.strings,
    required this.anchor,
    required this.initialDays,
    required this.initialHours,
    required this.initialMinutes,
  });

  final TasksUiPalette palette;
  final ScheduleStrings strings;
  final DateTime anchor;
  final int initialDays;
  final int initialHours;
  final int initialMinutes;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  late int _days;
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _hours = widget.initialHours;
    _minutes = widget.initialMinutes;
  }

  int get _totalMinutes => _days * 24 * 60 + _hours * 60 + _minutes;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final strings = widget.strings;
    final fire = reminderFireAt(widget.anchor, _totalMinutes);
    final when =
        '${fire.hour.toString().padLeft(2, '0')}:${fire.minute.toString().padLeft(2, '0')} on ${fire.day} ${monthShort(fire.month)}.';

    return Dialog(
      backgroundColor: palette.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.customReminder,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  _Wheel(
                    palette: palette,
                    count: 31,
                    value: _days,
                    suffix: strings.dayUnit,
                    onChanged: (v) => setState(() => _days = v),
                  ),
                  _Wheel(
                    palette: palette,
                    count: 24,
                    value: _hours,
                    suffix: strings.hourEarly.contains('hour') ? 'hrs' : 'год',
                    onChanged: (v) => setState(() => _hours = v),
                  ),
                  _Wheel(
                    palette: palette,
                    count: 60,
                    value: _minutes,
                    suffix: 'mins',
                    onChanged: (v) => setState(() => _minutes = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.remindAt(when),
              style: TextStyle(color: palette.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      strings.cancel,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _totalMinutes <= 0 && _days == 0
                        ? () => Navigator.pop(context, 0)
                        : () => Navigator.pop(context, _totalMinutes),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                    ),
                    child: Text(strings.add),
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

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.palette,
    required this.count,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  final TasksUiPalette palette;
  final int count;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              itemExtent: 32,
              scrollController: FixedExtentScrollController(initialItem: value),
              onSelectedItemChanged: onChanged,
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(
                      '$i',
                      style: TextStyle(color: palette.textPrimary, fontSize: 18),
                    ),
                  ),
              ],
            ),
          ),
          Text(suffix, style: TextStyle(color: palette.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
