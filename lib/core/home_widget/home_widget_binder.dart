import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../services/home_calendar_widget_service.dart';
import '../../viewmodels/habit_progress_viewmodel.dart';
import '../../viewmodels/tasks_viewmodel.dart';
import '../day_change_notifier.dart';
import '../deep_link/deep_link_action.dart';
import '../deep_link/deep_link_controller.dart';
import '../locale/locale_controller.dart';
import '../theme/theme_controller.dart';
import 'home_calendar_builder.dart';
import 'home_widget_link.dart';

/// Publishes tasks/habits to the home-screen widget and handles widget taps.
class HomeWidgetBinder extends StatefulWidget {
  const HomeWidgetBinder({super.key, required this.child});

  final Widget child;

  @override
  State<HomeWidgetBinder> createState() => _HomeWidgetBinderState();
}

class _HomeWidgetBinderState extends State<HomeWidgetBinder> {
  StreamSubscription<Uri?>? _clicks;
  Timer? _debounce;
  TasksViewModel? _tasks;
  HabitProgressViewModel? _habits;
  ThemeController? _theme;
  LocaleController? _locale;
  DayChangeNotifier? _dayChange;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listen();
      unawaited(_publish());
      unawaited(_consumeInitialLaunch());
    });
  }

  void _listen() {
    _tasks = context.read<TasksViewModel>()..addListener(_schedulePublish);
    _habits = context.read<HabitProgressViewModel>()
      ..addListener(_schedulePublish);
    _theme = context.read<ThemeController>()..addListener(_schedulePublish);
    _locale = context.read<LocaleController>()..addListener(_schedulePublish);
    _dayChange = context.read<DayChangeNotifier>()
      ..addListener(_schedulePublish);
    try {
      _clicks = HomeWidget.widgetClicked.listen(_onUri);
    } on MissingPluginException {
      // Tests / unsupported embeds.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_clicks?.cancel());
    _tasks?.removeListener(_schedulePublish);
    _habits?.removeListener(_schedulePublish);
    _theme?.removeListener(_schedulePublish);
    _locale?.removeListener(_schedulePublish);
    _dayChange?.removeListener(_schedulePublish);
    super.dispose();
  }

  void _schedulePublish() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_publish());
    });
  }

  Future<void> _publish() async {
    if (!mounted || kIsWeb) return;
    final tasks = context.read<TasksViewModel>();
    final habits = context.read<HabitProgressViewModel>();
    final theme = context.read<ThemeController>();
    final localeController = context.read<LocaleController>();
    final locale = localeController.localeOverride ?? const Locale('uk', 'UA');
    final snapshot = buildHomeCalendarSnapshot(
      tasks: tasks.tasks,
      themeColors: tasks.themeColors,
      habits: habits.habits,
      records: habits.records,
      palette: theme.palette,
      locale: locale,
      now: context.read<DayChangeNotifier>().today,
    );
    await const HomeCalendarWidgetService().publish(snapshot);
  }

  Future<void> _consumeInitialLaunch() async {
    if (kIsWeb) return;
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _onUri(uri);
    } on MissingPluginException {
      // Tests / unsupported embeds.
    }
  }

  void _onUri(Uri? uri) {
    final action = parseHomeWidgetLaunchUri(uri);
    if (action == null || !mounted) return;
    context.read<DeepLinkController>().enqueue(
      DeepLinkAction.homeWidget(action),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
