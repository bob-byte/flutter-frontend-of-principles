import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/progress_viewmodel.dart';

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});

  static const routeName = '/progress';

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Consumer<ProgressViewModel>(
        builder: (context, vm, child) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => vm.addProgress(0),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => vm.addProgress(1),
                    child: const Text('Yes'),
                  ),
                  ElevatedButton(
                    onPressed: () => vm.addProgress(500),
                    child: const Text('Numeric +500'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: vm.items.length,
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        return ListTile(
                          title: Text('Value: ${item.value}'),
                          subtitle: Text('DateInt: ${item.dateAsInt}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
