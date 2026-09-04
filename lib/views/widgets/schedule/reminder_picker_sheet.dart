import 'package:flutter/material.dart';

import '../../../core/theme/task_theme_palette.dart';
import '../../../l10n/schedule_strings.dart';
import '../../../models/schedule_reminder_offset.dart';
import 'custom_reminder_dialog.dart';
import 'reminder_recents_store.dart';
import 'schedule_format.dart';

class ReminderPickerResult {
  const ReminderPickerResult({
    required this.offsets,
    required this.constantReminder,
  });

  final List<ScheduleReminderOffset> offsets;
  final bool constantReminder;
}

Future<ReminderPickerResult?> showReminderPickerSheet(
  BuildContext context, {
  required TasksUiPalette palette,
  required List<ScheduleReminderOffset> selected,
  required bool constantReminder,
  DateTime? anchor,
}) {
  return showModalBottomSheet<ReminderPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReminderPickerSheet(
      palette: palette,
      initial: selected,
      constantReminder: constantReminder,
      anchor: anchor,
    ),
  );
}

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({
    required this.palette,
    required this.initial,
    required this.constantReminder,
    this.anchor,
  });

  final TasksUiPalette palette;
  final List<ScheduleReminderOffset> initial;
  final bool constantReminder;
  final DateTime? anchor;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late Set<int> _selected;
  late Map<int, int?> _ids;
  late bool _constant;
  List<int> _recents = const [];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.map((e) => e.offsetMinutes).toSet();
    _ids = {
      for (final e in widget.initial) e.offsetMinutes: e.notificationRequestId,
    };
    _constant = widget.constantReminder;
    ReminderRecentsStore.load().then((value) {
      if (mounted) setState(() => _recents = value);
    });
  }

  void _toggle(int minutes) {
    setState(() {
      if (_selected.contains(minutes)) {
        _selected.remove(minutes);
      } else {
        _selected.add(minutes);
      }
    });
  }

  void _selectNone() {
    setState(() {
      _selected.clear();
      _constant = false;
    });
  }

  List<ScheduleReminderOffset> _buildOffsets() {
    final list = _selected.toList()..sort();
    return [
      for (final m in list)
        ScheduleReminderOffset(
          offsetMinutes: m,
          notificationRequestId: _ids[m],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = ScheduleStrings.of(context);
    final palette = widget.palette;
    final presetMinutes = ReminderPresets.defaults;
    final extraRecents = _recents
        .where((m) => !presetMinutes.contains(m) && m != 0)
        .toList();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Material(
      color: palette.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Row(
                          palette: palette,
                          label: strings.none,
                          selected: _selected.isEmpty,
                          onTap: () {
                            _selectNone();
                            Navigator.pop(
                              context,
                              const ReminderPickerResult(
                                offsets: [],
                                constantReminder: false,
                              ),
                            );
                          },
                        ),
                        for (final minutes in presetMinutes)
                          _Row(
                            palette: palette,
                            label: formatOffsetLabel(strings, minutes),
                            selected: _selected.contains(minutes),
                            onTap: () => _toggle(minutes),
                          ),
                        _Row(
                          palette: palette,
                          label: strings.custom,
                          selected: false,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: palette.textMuted,
                          ),
                          onTap: () async {
                            final custom = await showCustomReminderDialog(
                              context,
                              palette: palette,
                              anchor: widget.anchor,
                            );
                            if (custom == null) return;
                            await ReminderRecentsStore.add(custom);
                            setState(() {
                              _selected.add(custom);
                              _recents = [
                                custom,
                                ..._recents.where((e) => e != custom),
                              ];
                            });
                          },
                        ),
                        if (extraRecents.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                strings.recents,
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          for (final minutes in extraRecents)
                            _Row(
                              palette: palette,
                              label: formatOffsetLabel(strings, minutes),
                              selected: _selected.contains(minutes),
                              onTap: () => _toggle(minutes),
                            ),
                        ],
                        SwitchListTile.adaptive(
                          title: Text(
                            strings.constantReminder,
                            style: TextStyle(color: palette.textPrimary),
                          ),
                          value: _constant,
                          activeThumbColor: palette.primary,
                          onChanged: (v) => setState(() => _constant = v),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ReminderPickerResult(
                        offsets: _buildOffsets(),
                        constantReminder: _constant && _selected.isNotEmpty,
                      ),
                    ),
                    child: Text(
                      strings.done,
                      style: TextStyle(color: palette.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final TasksUiPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? palette.primary : palette.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing:
          trailing ??
          (selected
              ? Icon(Icons.check, color: palette.primary, size: 20)
              : null),
      onTap: onTap,
    );
  }
}
