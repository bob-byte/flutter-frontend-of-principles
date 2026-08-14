import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frequency_config.dart';
import '../../viewmodels/frequency_dialog_viewmodel.dart';

class FrequencyDialogWidget extends StatelessWidget {
  final FrequencyConfig initialConfig;

  const FrequencyDialogWidget({super.key, required this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FrequencyDialogViewModel()..init(initialConfig),
      child: const _FrequencyDialogContent(),
    );
  }
}

class _FrequencyDialogContent extends StatelessWidget {
  const _FrequencyDialogContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FrequencyDialogViewModel>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.only(top: 16, bottom: 16, left: 12, right: 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRadioRow(
            context,
            FrequencyType.daily,
            const Text('Кожного дня', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          _buildRadioRow(
            context,
            FrequencyType.everyXDays,
            Row(
              children: [
                const Text('Кожні', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  height: 36,
                  child: TextField(
                    controller: vm.daysController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onTap: () => context.read<FrequencyDialogViewModel>().setFrequencyType(FrequencyType.everyXDays),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('дні(-ів)', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildRadioRow(
            context,
            FrequencyType.timesPerPeriod,
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 36,
                  child: TextField(
                    controller: vm.timesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onTap: () => context.read<FrequencyDialogViewModel>().setFrequencyType(FrequencyType.timesPerPeriod),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('рази(-ів) на', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PeriodType>(
                        value: vm.selectedPeriod,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        onChanged: (val) {
                          if (val != null) {
                            context.read<FrequencyDialogViewModel>().setPeriodType(val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: PeriodType.week, child: Text('тиждень')),
                          DropdownMenuItem(value: PeriodType.month, child: Text('місяць')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => vm.completeDialog(confirmed: false),
                icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
                label: const Text('Скасувати', style: TextStyle(color: Colors.white, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade400,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => vm.completeDialog(confirmed: true),
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                label: const Text('Зберегти', style: TextStyle(color: Colors.white, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioRow(BuildContext context, FrequencyType value, Widget child) {
    final vm = context.watch<FrequencyDialogViewModel>();
    return GestureDetector(
      onTap: () => context.read<FrequencyDialogViewModel>().setFrequencyType(value),
      child: Row(
        children: [
          Radio<FrequencyType>(
            value: value,
            groupValue: vm.selectedType,
            onChanged: (val) => context.read<FrequencyDialogViewModel>().setFrequencyType(val!),
            activeColor: Colors.blue,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
