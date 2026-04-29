import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/recommended_habit.dart';
import '../viewmodels/edit_habit_viewmodel.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editHabitTitle)),
      body: Consumer<EditHabitViewModel>(
        builder: (context, vm, child) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(labelText: l10n.habitNameLabel),
                onChanged: (value) => vm.habitName = value,
                controller: TextEditingController(text: vm.habitName)
                  ..selection = TextSelection.collapsed(offset: vm.habitName.length),
              ),
              TextField(
                decoration: InputDecoration(labelText: l10n.habitDescriptionLabel),
                maxLines: 3,
                onChanged: (value) => vm.habitDescription = value,
                controller: TextEditingController(text: vm.habitDescription)
                  ..selection = TextSelection.collapsed(offset: vm.habitDescription.length),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.isSaving ? null : () => vm.saveHabit(defaultFrequencyText: l10n.defaultFrequencyEveryDay),
                      child: Text(l10n.saveButton),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.isRecommendationLoading
                          ? null
                          : () => vm.loadRecommendations(localizedFallbacks: localizedRecommendations),
                      child: vm.isRecommendationLoading
                          ? const CircularProgressIndicator()
                          : Text(l10n.recommendedHabitsButton),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(HabitDetailView.routeName),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l10n.openHabitDetailsButton),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: vm.recommendations.length,
                  itemBuilder: (_, index) {
                    final item = vm.recommendations[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(item.reasonToFollow),
                      onTap: () => vm.applyRecommendation(item),
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
