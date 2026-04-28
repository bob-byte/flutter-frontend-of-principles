import 'package:flutter/material.dart';

import '../views/edit_habit_view.dart';
import '../views/goals_view.dart';
import '../views/helper_view.dart';
import '../views/habit_detail_view.dart';
import '../views/login_view.dart';
import '../views/progress_view.dart';
import '../views/settings_view.dart';
import '../views/startup_view.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case StartupView.routeName:
        return MaterialPageRoute(builder: (_) => const StartupView());
      case LoginView.routeName:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case HelperView.routeName:
        return MaterialPageRoute(builder: (_) => const HelperView());
      case HabitDetailView.routeName:
        return MaterialPageRoute(builder: (_) => const HabitDetailView());
      case EditHabitView.routeName:
        return MaterialPageRoute(builder: (_) => const EditHabitView());
      case GoalsView.routeName:
        return MaterialPageRoute(builder: (_) => const GoalsView());
      case ProgressView.routeName:
        return MaterialPageRoute(builder: (_) => const ProgressView());
      case SettingsView.routeName:
        return MaterialPageRoute(builder: (_) => const SettingsView());
      default:
        return MaterialPageRoute(builder: (_) => const StartupView());
    }
  }
}
