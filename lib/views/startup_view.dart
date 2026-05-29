import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/startup_viewmodel.dart';
import 'app_benefits_view.dart';
import 'helper_view.dart';
import 'login_view.dart';

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  static const routeName = '/';

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<StartupViewModel>();
      final nextRoute = await vm.initialize();
      if (!mounted) return;
      switch (nextRoute) {
        case StartupNextRoute.helper:
          Navigator.of(context).pushReplacementNamed(HelperView.routeName);
          break;
        case StartupNextRoute.login:
          Navigator.of(context).pushReplacementNamed(LoginView.routeName);
          break;
        case StartupNextRoute.appBenefits:
          Navigator.of(context).pushReplacementNamed(AppBenefitsView.routeName);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
