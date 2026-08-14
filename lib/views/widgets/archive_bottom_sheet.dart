import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../services/database_service.dart';
import '../../services/habit_service.dart';
import '../../viewmodels/archive_viewmodel.dart';
import '../edit_habit_view.dart';

class ArchiveBottomSheet extends StatelessWidget {
  const ArchiveBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ArchiveViewModel(
        DatabaseService(),
        ctx.read<HabitService>(),
      ),
      child: const _ArchiveBottomSheetContent(),
    );
  }
}

class _ArchiveBottomSheetContent extends StatelessWidget {
  const _ArchiveBottomSheetContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArchiveViewModel>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.info, size: 28),
                onPressed: vm.showBanner,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Text(
                'Архів',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, size: 28),
                onPressed: () {
                  // Відкрити створення звички, можливо з параметром isArchived = true, 
                  // але зазвичай просто відкривається створення.
                  // Тут можна викликати _dialogService або Navigator.
                  Navigator.pop(context); // Закрити архів і відкрити створення
                  EditHabitView.show(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // List
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.archivedHabits.isEmpty
                    ? const Center(child: Text('Архів порожній', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: vm.archivedHabits.length,
                        itemBuilder: (context, index) {
                          final habit = vm.archivedHabits[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: ListTile(
                              leading: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => vm.deleteHabit(habit),
                              ),
                              title: Text(habit.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  // Open EditHabitView for this habit
                                  // TODO: Add support for passing existing habit to EditHabitView
                                },
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Відновити звичку?'),
                                    content: const Text('Звичка буде перенесена на головний екран.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Ні'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          vm.unarchiveHabit(habit);
                                        },
                                        child: const Text('Так'),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
