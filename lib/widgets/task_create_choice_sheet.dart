import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';
import '../viewmodels/tasks_viewmodel.dart';
import 'tasks_glass.dart';

enum TaskCreateMode { manual, ai }

Future<TaskCreateMode?> showTaskCreateChoiceSheet(BuildContext context) {
  final vm = context.read<TasksViewModel>();
  return showModalBottomSheet<TaskCreateMode>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Theme(
      data: vm.themeData,
      child: const TaskCreateChoiceSheet(),
    ),
  );
}

class TaskCreateChoiceSheet extends StatelessWidget {
  const TaskCreateChoiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    final palette = context.watch<TasksViewModel>().palette;

    return TasksGlassSheet(
      palette: palette,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                strings.taskCreateHowTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.taskCreateHowHint,
                style: TextStyle(fontSize: 14, color: palette.textMuted),
              ),
              const SizedBox(height: 18),
              _ChoiceTile(
                palette: palette,
                icon: Icons.edit_outlined,
                title: strings.taskCreateManual,
                subtitle: strings.taskCreateManualHint,
                onTap: () => Navigator.pop(context, TaskCreateMode.manual),
              ),
              const SizedBox(height: 10),
              _ChoiceTile(
                palette: palette,
                icon: Icons.auto_awesome,
                title: strings.taskCreateWithAi,
                subtitle: strings.taskCreateWithAiHint,
                accent: true,
                onTap: () => Navigator.pop(context, TaskCreateMode.ai),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return TasksGlassPanel(
      palette: palette,
      borderRadius: BorderRadius.circular(18),
      blur: 20,
      tint: accent
          ? palette.primary.withValues(alpha: palette.isDark ? 0.28 : 0.55)
          : palette.glassChipFill,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: accent ? palette.primaryGradient : null,
              color: accent ? null : palette.glassFill,
            ),
            child: Icon(
              icon,
              color: accent ? palette.onPrimary : palette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textMuted),
        ],
      ),
    );
  }
}
