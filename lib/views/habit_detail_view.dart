import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/road_guide/road_guide_controller.dart';
import '../core/road_guide/road_guide_steps.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';
import '../models/habit.dart';
import '../viewmodels/habit_detail_viewmodel.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/app_loading_indicator.dart';
import 'edit_habit_view.dart';

class HabitDetailView extends StatefulWidget {
  const HabitDetailView({super.key, this.embedded = false});

  static const routeName = '/habit-detail';

  final bool embedded;

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
    final vm = context.read<HabitDetailViewModel>();
    final l10n = AppLocalizations.of(context)!;
    // Defer VM updates: didChangeDependencies runs during build, and
    // notifyListeners() mid-build throws on HabitDetailViewModel's Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (habitId == RoadGuideDemoIds.habitId) {
        vm.showPreview(roadGuideDemoHabit(l10n));
        return;
      }
      vm.load(localHabitId: habitId);
    });
  }

  List<String> _weekdayLabels(AppLocalizations l10n) => [
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];

  void _showInfo(BuildContext context, TasksUiPalette palette, String message) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: palette.onPrimary)),
        backgroundColor: palette.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: l10n.okButton,
          textColor: palette.onPrimary,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  void _showConfirmDialog({
    required BuildContext context,
    required TasksUiPalette palette,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showAppConfirmDialog(
      context: context,
      palette: palette,
      title: title,
      message: message,
      onConfirm: onConfirm,
    );
  }

  void _confirmArchive(
    BuildContext context,
    HabitDetailViewModel vm,
    TasksUiPalette palette,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final archived = vm.habit?.isArchived ?? false;
    _showConfirmDialog(
      context: context,
      palette: palette,
      title: archived ? l10n.unarchiveHabitQuestion : l10n.archiveHabitQuestion,
      message: archived ? l10n.unarchiveHabitMessage : l10n.archiveHabitMessage,
      onConfirm: () async {
        await vm.toggleArchived();
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    HabitDetailViewModel vm,
    TasksUiPalette palette,
  ) {
    final l10n = AppLocalizations.of(context)!;
    _showConfirmDialog(
      context: context,
      palette: palette,
      title: l10n.deleteHabitQuestion,
      message: l10n.deleteHabitMessage,
      onConfirm: () async {
        final deleted = await vm.deleteHabit();
        if (deleted && context.mounted) Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<HabitDetailViewModel>();
    final guideActive = context.watch<RoadGuideController>().isActive;
    final primaryBrightness = ThemeData.estimateBrightnessForColor(
      palette.primary,
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: primaryBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: primaryBrightness,
        ),
        leading: widget.embedded
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.onPrimary.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left, color: palette.onPrimary),
                ),
              ),
        title: Text(
          l10n.habitDetailsFallbackTitle,
          style: TextStyle(
            color: palette.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: (vm.habit?.isArchived ?? false)
                ? l10n.unarchiveTooltip
                : l10n.archiveTooltip,
            icon: Icon(
              (vm.habit?.isArchived ?? false)
                  ? Icons.unarchive_outlined
                  : Icons.inventory_2_outlined,
            ),
            onPressed: (vm.habit == null || guideActive)
                ? null
                : () => _confirmArchive(context, vm, palette),
          ),
          IconButton(
            tooltip: l10n.deleteTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: (vm.habit == null || guideActive)
                ? null
                : () => _confirmDelete(context, vm, palette),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: (vm.habit == null || guideActive)
            ? null
            : () async {
                await EditHabitView.show(context, habit: vm.habit);
                if (context.mounted && vm.habit?.id != null) {
                  vm.load(localHabitId: vm.habit!.id);
                }
              },
        child: Icon(Icons.edit, color: palette.onPrimary),
      ),
      body: vm.isLoading && vm.habit == null
          ? const AppLoadingIndicator()
          : vm.habit == null
          ? Center(
              child: Text(
                l10n.noHabitSelected,
                style: TextStyle(color: palette.textMuted),
              ),
            )
          : _HabitDetailBody(
              vm: vm,
              palette: palette,
              l10n: l10n,
              weekdayLabels: _weekdayLabels(l10n),
              onShowInfo: (message) => _showInfo(context, palette, message),
            ),
    );

    if (widget.embedded) return scaffold;

    return Stack(
      fit: StackFit.expand,
      children: [const AppLiquidBackground(), scaffold],
    );
  }
}

class _HabitDetailBody extends StatelessWidget {
  const _HabitDetailBody({
    required this.vm,
    required this.palette,
    required this.l10n,
    required this.weekdayLabels,
    required this.onShowInfo,
  });

  final HabitDetailViewModel vm;
  final TasksUiPalette palette;
  final AppLocalizations l10n;
  final List<String> weekdayLabels;
  final void Function(String message) onShowInfo;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final reminderLabels = formatReminderChips(vm.habit!, weekdayLabels);
    final frequencyLabel = formatFrequencyLabel(vm.habit!.frequency, l10n);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                palette: palette,
                icon: Icons.calendar_month,
                label: frequencyLabel,
              ),
              for (final label in reminderLabels)
                _InfoChip(
                  palette: palette,
                  icon: Icons.access_time,
                  label: label,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _HabitMetaCard(habit: vm.habit!, palette: palette, l10n: l10n),
          const SizedBox(height: 24),
          _SectionTitle(text: l10n.overallProgress, color: palette.textPrimary),
          const SizedBox(height: 8),
          _OverallProgressCard(vm: vm, palette: palette, l10n: l10n),
          const SizedBox(height: 28),
          _SectionTitle(
            text: l10n.topFiveStreaks,
            color: palette.textPrimary,
            onInfo: () => onShowInfo(l10n.topFiveStreaksInfo),
            infoColor: palette.textMuted,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: vm.topFiveStreaks.isEmpty
                ? _EmptyChart(label: l10n.noStreaksYet, palette: palette)
                : _TopFiveStreaksChart(
                    streaks: vm.topFiveStreaks,
                    palette: palette,
                    axisTitle: l10n.executionCountAxis,
                    locale: locale,
                  ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            text: l10n.stabilityTitle,
            color: palette.textPrimary,
            onInfo: () => onShowInfo(l10n.stabilityInfo),
            infoColor: palette.textMuted,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: vm.stabilitySeries.isEmpty
                ? _EmptyChart(label: l10n.noStabilityData, palette: palette)
                : _StabilityChart(
                    points: vm.stabilitySeries,
                    palette: palette,
                    locale: locale,
                  ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            text: l10n.habitByWeekdays,
            color: palette.textPrimary,
            onInfo: () => onShowInfo(l10n.habitByWeekdaysInfo),
            infoColor: palette.textMuted,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: _WeekdaysChart(
              counts: vm.weekDayExecution,
              labels: weekdayLabels,
              palette: palette,
              axisTitle: l10n.executionCountAxis,
            ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            text: l10n.calendarTitle,
            color: palette.textPrimary,
            onInfo: () => onShowInfo(l10n.calendarInfo),
            infoColor: palette.textMuted,
          ),
          const SizedBox(height: 12),
          _HabitCalendar(
            vm: vm,
            palette: palette,
            weekdayLabels: weekdayLabels,
            locale: locale,
          ),
        ],
      ),
    );
  }
}

class _HabitMetaCard extends StatelessWidget {
  const _HabitMetaCard({
    required this.habit,
    required this.palette,
    required this.l10n,
  });

  final Habit habit;
  final TasksUiPalette palette;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final notes = habit.notes.trim();
    final goal = habit.targetGoal.trim();
    final typeLabel = habit.isFlexible
        ? l10n.habitFlexible
        : l10n.habitNoExceptions;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: palette.glassShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.name,
            key: const Key('habitDetailFullName'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.25,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _HabitMetaRow(
            icon: Icons.flag_outlined,
            label: l10n.habitGoalLabel,
            value: goal.isEmpty ? l10n.habitGoalEmpty : goal,
            muted: goal.isEmpty,
            palette: palette,
            valueKey: const Key('habitDetailGoal'),
          ),
          const SizedBox(height: 12),
          _HabitMetaRow(
            icon: habit.isFlexible ? Icons.alt_route : Icons.gavel,
            label: l10n.habitTypeLabel,
            value: typeLabel,
            palette: palette,
            valueKey: const Key('habitDetailType'),
          ),
          const SizedBox(height: 12),
          _HabitMetaRow(
            icon: Icons.notes_outlined,
            label: l10n.habitNotes,
            value: notes.isEmpty ? l10n.habitNotesEmpty : notes,
            muted: notes.isEmpty,
            palette: palette,
            valueKey: const Key('habitDetailNotes'),
          ),
          const SizedBox(height: 12),
          _HabitMetaRow(
            icon: Icons.bar_chart,
            label: l10n.habitComplexityLabel,
            value: '${habit.difficulty}',
            palette: palette,
            valueKey: const Key('habitDetailComplexity'),
          ),
        ],
      ),
    );
  }
}

class _HabitMetaRow extends StatelessWidget {
  const _HabitMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
    this.muted = false,
    this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final TasksUiPalette palette;
  final bool muted;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                key: valueKey,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: muted ? palette.textMuted : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.text,
    required this.color,
    this.onInfo,
    this.infoColor,
  });

  final String text;
  final Color color;
  final VoidCallback? onInfo;
  final Color? infoColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        if (onInfo != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onInfo,
            customBorder: const CircleBorder(),
            child: Icon(Icons.info, size: 18, color: infoColor ?? color),
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.palette,
    required this.icon,
    required this.label,
  });

  final TasksUiPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: palette.isDark ? 0.42 : 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.onPrimary, size: 16),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 96,
            ),
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: palette.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({
    required this.vm,
    required this.palette,
    required this.l10n,
  });

  final HabitDetailViewModel vm;
  final TasksUiPalette palette;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: palette.glassShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vm.percentageLabel,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vm.completionRate,
              backgroundColor: palette.softBg,
              color: palette.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.executionCount(vm.completedDays),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.longestStreak(vm.longestStreak),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.label, required this.palette});

  final String label;
  final TasksUiPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: TextStyle(color: palette.textMuted)),
    );
  }
}

class _TopFiveStreaksChart extends StatelessWidget {
  const _TopFiveStreaksChart({
    required this.streaks,
    required this.palette,
    required this.axisTitle,
    required this.locale,
  });

  final List<StreakStat> streaks;
  final TasksUiPalette palette;
  final String axisTitle;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final rawMax = streaks
        .map((s) => s.days.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final tickMax = niceChartMax(rawMax);
    final interval = chartInterval(tickMax);
    final maxY = tickMax * 1.2;
    final gridColor = palette.cardBorder.withValues(alpha: 0.45);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= streaks.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Transform.rotate(
                    angle: -0.7,
                    child: Text(
                      formatStreakRange(streaks[index], locale),
                      style: TextStyle(fontSize: 9, color: palette.textMuted),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              axisTitle,
              style: TextStyle(fontSize: 11, color: palette.textMuted),
            ),
            axisNameSize: 22,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value > tickMax + 0.01 || value < 0) {
                  return const SizedBox.shrink();
                }
                if ((value / interval).roundToDouble() != value / interval &&
                    value != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          checkToShowHorizontalLine: (value) => value <= tickMax + 0.01,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(streaks.length, (index) {
          return BarChartGroupData(
            x: index,
            showingTooltipIndicators: [0],
            barRods: [
              BarChartRodData(
                toY: streaks[index].days.toDouble(),
                color: palette.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StabilityChart extends StatelessWidget {
  const _StabilityChart({
    required this.points,
    required this.palette,
    required this.locale,
  });

  final List<StabilityPoint> points;
  final TasksUiPalette palette;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', locale);
    final labelStep = points.length <= 5
        ? 1
        : (points.length / 5).ceil().clamp(1, points.length);
    final gridColor = palette.cardBorder.withValues(alpha: 0.45);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final isLast = index == points.length - 1;
                if (index % labelStep != 0 && !isLast) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.6,
                    child: Text(
                      dateFormat.format(points[index].date),
                      style: TextStyle(fontSize: 9, color: palette.textMuted),
                    ),
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
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].percent),
            ],
            isCurved: false,
            color: palette.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class _WeekdaysChart extends StatelessWidget {
  const _WeekdaysChart({
    required this.counts,
    required this.labels,
    required this.palette,
    required this.axisTitle,
  });

  final List<int> counts;
  final List<String> labels;
  final TasksUiPalette palette;
  final String axisTitle;

  @override
  Widget build(BuildContext context) {
    final values = List<int>.from(counts);
    while (values.length < 7) {
      values.add(0);
    }
    final rawMax = values
        .map((v) => v.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final tickMax = niceChartMax(rawMax);
    final interval = chartInterval(tickMax);
    final maxY = tickMax * 1.2;
    final gridColor = palette.cardBorder.withValues(alpha: 0.45);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index > 6) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[index],
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              axisTitle,
              style: TextStyle(fontSize: 11, color: palette.textMuted),
            ),
            axisNameSize: 22,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value > tickMax + 0.01 || value < 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          checkToShowHorizontalLine: (value) => value <= tickMax + 0.01,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          return BarChartGroupData(
            x: index,
            showingTooltipIndicators: values[index] > 0 ? [0] : [],
            barRods: [
              BarChartRodData(
                toY: values[index].toDouble(),
                color: palette.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _HabitCalendar extends StatelessWidget {
  const _HabitCalendar({
    required this.vm,
    required this.palette,
    required this.weekdayLabels,
    required this.locale,
  });

  final HabitDetailViewModel vm;
  final TasksUiPalette palette;
  final List<String> weekdayLabels;
  final String locale;

  Future<void> _onDayTapped(BuildContext context, DateTime date) async {
    final result = await vm.toggleCalendarDay(date);
    if (result != CalendarDayTapResult.futureDate || !context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog.message(
        palette: palette,
        title: l10n.errorTitle,
        message: l10n.cannotCompleteHabitInTheFuture,
        buttonLabel: l10n.okButton,
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = vm.currentMonth.year;
    final month = vm.currentMonth.month;
    final monthName = DateFormat('MMMM', locale).format(vm.currentMonth);
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayIndex = firstDay.weekday - 1;
    final rowCount = ((firstDayIndex + daysInMonth + 6) ~/ 7);

    return Container(
      decoration: BoxDecoration(
        color: palette.softBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: palette.onPrimary),
                  onPressed: () => vm.changeMonth(-1),
                ),
                Column(
                  children: [
                    Text(
                      year.toString(),
                      style: TextStyle(
                        color: palette.onPrimary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      monthName,
                      style: TextStyle(
                        color: palette.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: palette.onPrimary),
                  onPressed: () => vm.changeMonth(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: weekdayLabels
                  .map(
                    (day) => Expanded(
                      child: Text(
                        day.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          GridView.builder(
            padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayIndex ||
                  index >= firstDayIndex + daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = index - firstDayIndex + 1;
              final date = DateTime(year, month, day);
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isCompleted = vm.completedCalendarDays.contains(date);

              return Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _onDayTapped(context, date),
                    child: Container(
                      width: 35,
                      height: 35,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCompleted ? palette.primary : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontWeight: isCompleted || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCompleted
                              ? palette.onPrimary
                              : palette.textPrimary,
                          decoration: isToday
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: isCompleted
                              ? palette.onPrimary
                              : palette.textPrimary,
                        ),
                      ),
                    ),
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
