import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
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
                    child: Text(l10n.progressNo),
                  ),
                  ElevatedButton(
                    onPressed: () => vm.addProgress(1),
                    child: Text(l10n.progressYes),
                  ),
                  ElevatedButton(
                    onPressed: () => vm.addProgress(500),
                    child: Text(l10n.progressNumeric500),
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
                          title: Text(l10n.progressValue(item.value.toString())),
                          subtitle: Text(l10n.progressDateInt(item.dateAsInt)),
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
