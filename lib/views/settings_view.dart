import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/settings_viewmodel.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().loadTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, child) => ListView(
          children: [
            ListTile(
              title: const Text('Theme'),
              subtitle: const Text('Switch between dark and light'),
              trailing: DropdownButton<ThemeMode>(
                value: vm.themeMode,
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark (black + orange)')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    vm.setTheme(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
