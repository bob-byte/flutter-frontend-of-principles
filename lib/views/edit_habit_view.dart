import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/recommended_habit.dart';
import '../viewmodels/edit_habit_viewmodel.dart';
import '../widgets/app_liquid_background.dart';
import '../widgets/ui_theme_switcher.dart';
import 'habit_detail_view.dart';

class EditHabitView extends StatelessWidget {
  const EditHabitView({super.key});

  static const routeName = '/edit-habit';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localizedRecommendations = <RecommendedHabit>[
      RecommendedHabit(name: l10n.recommendedHabitName1, reasonToFollow: l10n.recommendedHabitReason1),
      RecommendedHabit(name: l10n.recommendedHabitName2, reasonToFollow: l10n.recommendedHabitReason2),
      RecommendedHabit(name: l10n.recommendedHabitName3, reasonToFollow: l10n.recommendedHabitReason3),
      RecommendedHabit(name: l10n.recommendedHabitName4, reasonToFollow: l10n.recommendedHabitReason4),
    ];

    return GlassScaffold(
      background: const AppLiquidBackground(),
      appBar: GlassAppBar(
        title: Text(l10n.editHabitTitle),
        leading: GlassIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          GlassIconButton(
            icon: const Icon(Icons.insights_outlined),
            semanticLabel: l10n.openHabitDetailsButton,
            onPressed: () =>
                Navigator.of(context).pushNamed(HabitDetailView.routeName),
          ),
          const AppThemeSwitcher(),
        ],
      ),
      body: Consumer<EditHabitViewModel>(
        builder: (context, vm, child) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassTextField(
                useOwnLayer: true,
                placeholder: l10n.habitNameLabel,
                controller: TextEditingController(text: vm.habitName)
                  ..selection =
                      TextSelection.collapsed(offset: vm.habitName.length),
                onChanged: (value) => vm.habitName = value,
              ),
              const SizedBox(height: 10),
              GlassTextField(
                useOwnLayer: true,
                placeholder: l10n.habitDescriptionLabel,
                maxLines: 3,
                minLines: 3,
                controller: TextEditingController(text: vm.habitDescription)
                  ..selection = TextSelection.collapsed(
                    offset: vm.habitDescription.length,
                  ),
                onChanged: (value) => vm.habitDescription = value,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassButton.custom(
                      useOwnLayer: true,
                      width: null,
                      height: 48,
                      enabled: !vm.isSaving,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                      label: l10n.saveButton,
                      onTap: () => vm.saveHabit(
                        defaultFrequencyText: l10n.defaultFrequencyEveryDay,
                      ),
                      child: Text(l10n.saveButton),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton.custom(
                      useOwnLayer: true,
                      width: null,
                      height: 48,
                      enabled: !vm.isRecommendationLoading,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                      label: l10n.recommendedHabitsButton,
                      onTap: () => vm.loadRecommendations(
                        localizedFallbacks: localizedRecommendations,
                      ),
                      child: vm.isRecommendationLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.recommendedHabitsButton,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: vm.recommendations.length,
                  itemBuilder: (_, index) {
                    final item = vm.recommendations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassListTile.standalone(
                        title: Text(item.name),
                        subtitle: Text(item.reasonToFollow),
                        onTap: () => vm.applyRecommendation(item),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
