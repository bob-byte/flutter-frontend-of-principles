import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/helper_viewmodel.dart';
import '../widgets/themed_lottie.dart';
import 'edit_habit_view.dart';

class HelperView extends StatefulWidget {
  const HelperView({super.key, this.embedded = false});

  static const routeName = '/helper';

  final bool embedded;

  @override
  State<HelperView> createState() => _HelperViewState();
}

class _HelperViewState extends State<HelperView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(HelperViewModel vm, AppLocalizations l10n) async {
    final prompt = _controller.text;
    _controller.clear();
    await vm.ask(
      prompt,
      fallbackAnswer: l10n.chatFallbackAnswer,
      errorMessage: l10n.genericErrorOccurred,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _HelperBody(controller: _controller, onSend: _send);

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(title: Text(l10n.helperTitle)),
            Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(l10n.helperTitle),
        actions: [
          GlassIconButton(
            icon: const Icon(Icons.auto_awesome),
            semanticLabel: l10n.editHabitTitle,
            onPressed: () =>
                Navigator.of(context).pushNamed(EditHabitView.routeName),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _HelperBody extends StatelessWidget {
  const _HelperBody({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function(HelperViewModel vm, AppLocalizations l10n) onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<HelperViewModel>(
      builder: (context, vm, child) => Column(
        children: [
          Expanded(
            child: vm.messages.isEmpty
                ? const Center(
                    child: ThemedLottie(
                      assetPath: 'assets/lottie/emptychat_light.json',
                      width: 220,
                      height: 220,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: vm.messages.length,
                    itemBuilder: (_, index) {
                      final msg = vm.messages[index];

                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            child: msg.isUser
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                : GlassCard(
                                    useOwnLayer: true,
                                    padding: const EdgeInsets.all(12),
                                    child: Text(msg.text),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    useOwnLayer: true,
                    controller: controller,
                    placeholder: l10n.helperInputHint,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(vm, l10n),
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icon(
                    vm.isBusy ? Icons.stop_circle_outlined : Icons.send,
                  ),
                  onPressed: vm.isBusy ? vm.cancel : () => onSend(vm, l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
