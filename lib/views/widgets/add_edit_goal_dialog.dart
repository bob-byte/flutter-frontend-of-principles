import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_goal.dart';
import '../../viewmodels/add_edit_goal_viewmodel.dart';
import '../../services/goal_service.dart';

class AddEditGoalDialogWidget extends StatelessWidget {
  final UserGoal? existingGoal;

  const AddEditGoalDialogWidget({super.key, this.existingGoal});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AddEditGoalViewModel(
        ctx.read<GoalService>(),
        existingGoal: existingGoal,
      ),
      child: const _AddEditGoalDialogContent(),
    );
  }
}

class _AddEditGoalDialogContent extends StatefulWidget {
  const _AddEditGoalDialogContent();

  @override
  State<_AddEditGoalDialogContent> createState() => _AddEditGoalDialogContentState();
}

class _AddEditGoalDialogContentState extends State<_AddEditGoalDialogContent> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final vm = context.read<AddEditGoalViewModel>();
    _controller = TextEditingController(text: vm.text)
      ..selection = TextSelection.collapsed(offset: vm.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddEditGoalViewModel>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(child: Text('Ціль', style: TextStyle(fontWeight: FontWeight.bold))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: '${vm.text.length}/255',
            ),
            onChanged: vm.updateText,
            maxLength: 255,
          ),
          const SizedBox(height: 12),
          const Text(
            'Приклади цілей спрямованих на вашу ідентичність: бути олімпійським чемпіоном, бути впевненим в собі, бути вільним від куріння.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton.icon(
          onPressed: vm.cancel,
          icon: const Icon(Icons.cancel, color: Colors.white),
          label: const Text('Скасувати', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400, shape: const StadiumBorder()),
        ),
        ElevatedButton.icon(
          onPressed: vm.text.trim().isNotEmpty ? vm.saveGoal : null,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: const Text('Зберегти', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: const StadiumBorder()),
        ),
      ],
    );
  }
}
