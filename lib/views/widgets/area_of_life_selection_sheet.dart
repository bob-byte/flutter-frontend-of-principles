import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/area_of_life.dart';
import '../../viewmodels/edit_habit_viewmodel.dart';
import '../../services/dialog_service.dart';

class AreaOfLifeSelectionSheet extends StatelessWidget {
  final List<AreaOfLife> initialSelectedAreas;

  const AreaOfLifeSelectionSheet({
    super.key,
    required this.initialSelectedAreas,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.read<EditHabitViewModel>();
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Areas of habit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, SheetResponse(confirmed: true, data: vm.selectedAreas));
                    },
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vm.allAreas.length,
                itemBuilder: (context, index) {
                  final area = vm.allAreas[index];
                  return Consumer<EditHabitViewModel>(
                    builder: (context, model, child) {
                      final isSelected = model.selectedAreas.contains(area);
                      return CheckboxListTile(
                        title: Text(area.name),
                        value: isSelected,
                        onChanged: (bool? value) {
                          model.toggleArea(area);
                        },
                      );
                    },
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
