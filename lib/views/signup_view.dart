import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/signup_viewmodel.dart';
import 'helper_view.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  static const routeName = '/signup';

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.startupRegisterBtn)),
      body: Consumer<SignupViewModel>(
        builder: (context, vm, child) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.emailLabel),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.passwordLabel),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: vm.isBusy
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final success = await vm.register(
                          _emailController.text,
                          _passwordController.text,
                          genericError: l10n.genericErrorOccurred,
                        );
                        if (!mounted) return;
                        if (success) {
                          navigator.pushReplacementNamed(HelperView.routeName);
                        }
                      },
                child: vm.isBusy
                    ? const CircularProgressIndicator()
                    : Text(l10n.startupRegisterBtn),
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 12),
                Text(vm.error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
