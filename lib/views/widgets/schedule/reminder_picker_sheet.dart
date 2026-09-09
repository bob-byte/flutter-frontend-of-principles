import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:super_tooltip/super_tooltip.dart';

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
}) async {
  // Updated on every toggle so barrier / swipe dismiss still applies.
  var latest = ReminderPickerResult(
    offsets: List<ScheduleReminderOffset>.from(selected),
    constantReminder: constantReminder,
  );
  final result = await showModalBottomSheet<ReminderPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReminderPickerSheet(
      palette: palette,
      initial: selected,
      constantReminder: constantReminder,
      anchor: anchor,
      onChanged: (value) => latest = value,
    ),
  );
  return result ?? latest;
}

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({
    required this.palette,
    required this.initial,
    required this.constantReminder,
    required this.onChanged,
    this.anchor,
  });

  final TasksUiPalette palette;
  final List<ScheduleReminderOffset> initial;
  final bool constantReminder;
  final ValueChanged<ReminderPickerResult> onChanged;
  final DateTime? anchor;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late Set<int> _selected;
  late Map<int, int?> _ids;
  late bool _constant;
  List<int> _recents = const [];
  final _constantInfoController = SuperTooltipController();

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

  @override
  void dispose() {
    _constantInfoController.dispose();
    super.dispose();
  }

  ReminderPickerResult _currentResult() {
    return ReminderPickerResult(
      offsets: _buildOffsets(),
      constantReminder: _constant && _selected.isNotEmpty,
    );
  }

  void _emit() => widget.onChanged(_currentResult());

  void _toggle(int minutes) {
    setState(() {
      if (_selected.contains(minutes)) {
        _selected.remove(minutes);
      } else {
        _selected.add(minutes);
      }
    });
    _emit();
  }

  void _selectNone() {
    setState(() {
      _selected.clear();
      _constant = false;
    });
    _emit();
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
    final l10n = AppLocalizations.of(context)!;
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
                            _emit();
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
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  strings.constantReminder,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              _ConstantReminderInfoButton(
                                controller: _constantInfoController,
                                message:
                                    l10n.scheduleConstantReminderExplanation,
                                okLabel: l10n.okButton,
                                iconColor: palette.textMuted,
                              ),
                            ],
                          ),
                          value: _constant,
                          activeThumbColor: palette.primary,
                          onChanged: (v) {
                            setState(() => _constant = v);
                            _emit();
                          },
                        ),
                      ],
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

class _ConstantReminderInfoButton extends StatelessWidget {
  const _ConstantReminderInfoButton({
    required this.controller,
    required this.message,
    required this.okLabel,
    required this.iconColor,
  });

  final SuperTooltipController controller;
  final String message;
  final String okLabel;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SuperTooltip(
      controller: controller,
      style: TooltipStyle(backgroundColor: scheme.primary, hasShadow: false),
      positionConfig: const PositionConfiguration(
        preferredDirection: TooltipDirection.up,
      ),
      content: SizedBox(
        width: 260,
        child: Material(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 13),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: () => controller.hideTooltip(),
                child: Text(
                  okLabel,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: IconButton(
        icon: Icon(Icons.info_outline, size: 18, color: iconColor),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: message,
        onPressed: () => controller.showTooltip(),
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
