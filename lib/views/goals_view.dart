import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/goals_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/themed_lottie.dart';

class GoalsView extends StatefulWidget {
  const GoalsView({super.key, this.embedded = false});

  static const routeName = '/goals';

  final bool embedded;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _GoalsBody(controller: _controller);

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassAppBar(title: Text(l10n.goalsTitle)),
            Expanded(child: body),
          ],
        ),
      );
    }

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.goalsTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: body,
    );
  }
}

class _GoalsBody extends StatelessWidget {
  const _GoalsBody({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<GoalsViewModel>(
      builder: (context, vm, child) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    useOwnLayer: true,
                    controller: controller,
                    placeholder: l10n.newGoalLabel,
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await vm.addGoal(controller.text);
                    controller.clear();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.isLoading
                ? const Center(
                    child: ThemedLottie(
                      assetPath: 'assets/lottie/loading.json',
                      width: 96,
                      height: 96,
                    ),
                  )
                : vm.goals.isEmpty
                ? const Center(
                    child: ThemedLottie(
                      assetPath: 'assets/lottie/goals.json',
                      width: 200,
                      height: 200,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: vm.goals.length,
                    itemBuilder: (context, index) {
                      final goal = vm.goals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassListTile.standalone(
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(goal.name),
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
