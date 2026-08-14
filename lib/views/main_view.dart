import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../viewmodels/main_viewmodel.dart';
import 'helper_view.dart';
import 'progress_view.dart';
import 'settings_view.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  static const routeName = '/main';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainViewModel(),
      child: const _MainViewContent(),
    );
  }
}

class _MainViewContent extends StatelessWidget {
  const _MainViewContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: vm.currentIndex,
        children: const [
          HelperView(),   // 0: ШІ-Помічник
          ProgressView(), // 1: Прогрес
          SettingsView(), // 2: Профіль
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: vm.currentIndex,
        onTap: vm.setIndex,
        selectedItemColor: Colors.blue, 
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.card_giftcard), 
            label: l10n.tabAssistant,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.show_chart), 
            label: l10n.tabProgress,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person), 
            label: l10n.tabProfile,
          ),
        ],
      ),
    );
  }
}
