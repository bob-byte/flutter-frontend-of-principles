import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/helper_viewmodel.dart';
import 'edit_habit_view.dart';
import 'goals_view.dart';
import 'habit_detail_view.dart';
import 'progress_view.dart';
import 'settings_view.dart';

class HelperView extends StatefulWidget {
  const HelperView({super.key});

  static const routeName = '/helper';

  @override
  State<HelperView> createState() => _HelperViewState();
}

class _HelperViewState extends State<HelperView> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat With Helper'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(EditHabitView.routeName),
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(GoalsView.routeName),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(ProgressView.routeName),
            icon: const Icon(Icons.show_chart),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(HabitDetailView.routeName),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(SettingsView.routeName),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Consumer<HelperViewModel>(
        builder: (context, vm, child) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: vm.messages.length,
                itemBuilder: (_, index) {
                  final msg = vm.messages[index];
                  return ListTile(
                    title: Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg.text),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Enter text'),
                      ),
                    ),
                  ),
                  vm.isBusy
                      ? IconButton(
                          onPressed: vm.cancel,
                          icon: const Icon(Icons.stop_circle_outlined),
                        )
                      : IconButton(
                          onPressed: () async {
                            final prompt = _controller.text;
                            _controller.clear();
                            await vm.ask(prompt);
                          },
                          icon: const Icon(Icons.send),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
