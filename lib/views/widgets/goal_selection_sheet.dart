import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_goal.dart';
import '../../viewmodels/goal_selection_viewmodel.dart';
import '../../services/goal_service.dart';

class GoalSelectionSheetWidget extends StatelessWidget {
  final String currentTargetGoal;

  const GoalSelectionSheetWidget({super.key, required this.currentTargetGoal});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => GoalSelectionViewModel(
        ctx.read<GoalService>(),
        currentTargetGoal: currentTargetGoal,
      ),
      child: const _GoalSelectionSheetContent(),
    );
  }
}

class _GoalSelectionSheetContent extends StatelessWidget {
  const _GoalSelectionSheetContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalSelectionViewModel>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Center(
                  child: Text('Оберіть Ціль Звички', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, size: 32, color: Colors.black),
                onPressed: () => vm.showAddEditGoalDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vm.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else if (vm.goals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Немає цілей', style: TextStyle(color: Colors.grey)),
            )
          else
            ...vm.goals.map((g) {
              final isSelected = vm.currentTargetGoal == g.name;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7EBAFF),
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected ? Border.all(color: Colors.blue, width: 2) : Border.all(color: Colors.black87, width: 1),
                ),
                child: ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.black87),
                    onPressed: () => vm.deleteGoal(g),
                  ),
                  title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.black87),
                    onPressed: () => vm.showAddEditGoalDialog(existingGoal: g),
                  ),
                  onTap: () => vm.selectGoal(g),
                ),
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'Рекомендація: виберіть конкретну ціль або ту, яка орієнтована на вашу ідентичність, оскільки вона визначає ваше життя.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
