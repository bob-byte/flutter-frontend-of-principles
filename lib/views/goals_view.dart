import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/goals_viewmodel.dart';

class GoalsView extends StatefulWidget {
  const GoalsView({super.key});

  static const routeName = '/goals';

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: Consumer<GoalsViewModel>(
        builder: (context, vm, child) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(labelText: 'New goal'),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await vm.addGoal(_controller.text);
                      _controller.clear();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: vm.goals.length,
                      itemBuilder: (context, index) {
                        final goal = vm.goals[index];
                        return ListTile(title: Text(goal.name));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
