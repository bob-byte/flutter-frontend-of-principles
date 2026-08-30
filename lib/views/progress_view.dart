import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/progress_viewmodel.dart';
import '../widgets/app_liquid_background.dart';

class ProgressView extends StatefulWidget {
  const ProgressView({super.key, this.embedded = false});

  static const routeName = '/progress';

  final bool embedded;

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
    const body = _ProgressBody();

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(title: Text(l10n.progressTitle)),
            const Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.progressTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: body,
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<ProgressViewModel>(
      builder: (context, vm, child) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: GlassButton.custom(
                    useOwnLayer: true,
                    width: null,
                    height: 44,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                    label: l10n.progressNo,
                    onTap: () => vm.addProgress(0),
                    child: Text(l10n.progressNo),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton.custom(
                    useOwnLayer: true,
                    width: null,
                    height: 44,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                    label: l10n.progressYes,
                    onTap: () => vm.addProgress(1),
                    child: Text(l10n.progressYes),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton.custom(
                    useOwnLayer: true,
                    width: null,
                    height: 44,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                    label: l10n.progressNumeric500,
                    onTap: () => vm.addProgress(500),
                    child: Text(l10n.progressNumeric500, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: vm.items.length,
                    itemBuilder: (context, index) {
                      final item = vm.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassListTile.standalone(
                          leading: const Icon(Icons.show_chart),
                          title: Text(l10n.progressValue(item.value.toString())),
                          subtitle: Text(l10n.progressDateInt(item.dateAsInt)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
