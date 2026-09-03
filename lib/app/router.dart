import 'package:flutter/material.dart';

import '../views/edit_habit_view.dart';
import '../views/goals_view.dart';
import '../views/app_benefits_view.dart';
import '../views/helper_view.dart';
import '../views/main_shell.dart';
import '../views/habit_detail_view.dart';
import '../views/login_view.dart';
import '../views/forget_password_view.dart';
import '../views/progress_view.dart';
import '../views/settings_view.dart';
import '../views/tasks_view.dart';
import '../views/startup_view.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case StartupView.routeName:
        return MaterialPageRoute(builder: (_) => const StartupView());
      case LoginView.routeName:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case AppBenefitsView.routeName:
        return MaterialPageRoute(builder: (_) => const AppBenefitsView());
      case HelperView.routeName:
        return MaterialPageRoute(builder: (_) => const MainShell());
      case HabitDetailView.routeName:
        return MaterialPageRoute(builder: (_) => const HabitDetailView());
      case EditHabitView.routeName:
        return MaterialPageRoute(builder: (_) => const EditHabitView());
      case GoalsView.routeName:
        return MaterialPageRoute(builder: (_) => const GoalsView());
      case TasksView.routeName:
        return MaterialPageRoute(builder: (_) => const TasksView());
      case ProgressView.routeName:
        return MaterialPageRoute(builder: (_) => const ProgressView());
      case SettingsView.routeName:
        return MaterialPageRoute(builder: (_) => const SettingsView());
      case ForgetPasswordView.routeName:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ForgetPasswordView(initialEmail: email),
        );
      default:
        return MaterialPageRoute(builder: (_) => const StartupView());
    }
  }
}
