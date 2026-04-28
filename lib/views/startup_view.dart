import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/startup_viewmodel.dart';
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
      final isLoggedIn = await vm.initialize();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        isLoggedIn ? HelperView.routeName : LoginView.routeName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
