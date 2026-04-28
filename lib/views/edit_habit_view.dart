import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/edit_habit_viewmodel.dart';
import 'habit_detail_view.dart';

class EditHabitView extends StatelessWidget {
  const EditHabitView({super.key});

  static const routeName = '/edit-habit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Habit')),
      body: Consumer<EditHabitViewModel>(
        builder: (context, vm, child) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Habit name'),
                onChanged: (value) => vm.habitName = value,
                controller: TextEditingController(text: vm.habitName)
                  ..selection = TextSelection.collapsed(offset: vm.habitName.length),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Description'),
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
                      onPressed: vm.isSaving ? null : vm.saveHabit,
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.isRecommendationLoading ? null : vm.loadRecommendations,
                      child: vm.isRecommendationLoading
                          ? const CircularProgressIndicator()
                          : const Text('Recommended Habits'),
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
                  label: const Text('Open habit details'),
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
