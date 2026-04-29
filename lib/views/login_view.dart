import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/login_viewmodel.dart';
import 'helper_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  static const routeName = '/login';

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Consumer<LoginViewModel>(
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
                        final success = await vm.login(
                          _emailController.text,
                          _passwordController.text,
                          invalidCredentialsError: l10n.invalidCredentialsError,
                        );
                        if (!mounted) return;
                        if (success) {
                          navigator.pushReplacementNamed(HelperView.routeName);
                        }
                      },
                child: vm.isBusy
                    ? const CircularProgressIndicator()
                    : Text(l10n.signInButton),
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
