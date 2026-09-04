import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frequency_config.dart';
import '../../viewmodels/frequency_dialog_viewmodel.dart';
import '../../widgets/app_alert_dialog.dart';

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
    final palette = appAlertPaletteOf(context);

    return AppAlertDialog(
      palette: palette,
      contentPadding: const EdgeInsets.only(
        top: 8,
        bottom: 16,
        left: 12,
        right: 12,
      ),
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
                    key: const Key('frequencyDaysField'),
                    controller: vm.daysController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textPrimary),
                    cursorColor: palette.primary,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTap: () => context
                        .read<FrequencyDialogViewModel>()
                        .setFrequencyType(FrequencyType.everyXDays),
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
                    key: const Key('frequencyTimesField'),
                    controller: vm.timesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textPrimary),
                    cursorColor: palette.primary,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onTap: () => context
                        .read<FrequencyDialogViewModel>()
                        .setFrequencyType(FrequencyType.timesPerPeriod),
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
                      color: palette.softBg,
                      border: Border.all(
                        color: palette.cardBorder.withValues(alpha: 0.7),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PeriodType>(
                        key: const Key('frequencyPeriodDropdown'),
                        value: vm.selectedPeriod,
                        isExpanded: true,
                        dropdownColor: palette.cardBg,
                        focusColor: palette.softBg,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.textPrimary,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: palette.textMuted,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            context
                                .read<FrequencyDialogViewModel>()
                                .setPeriodType(val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: PeriodType.week,
                            child: Text('тиждень'),
                          ),
                          DropdownMenuItem(
                            value: PeriodType.month,
                            child: Text('місяць'),
                          ),
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
                key: const Key('frequencyCancelButton'),
                onPressed: () => vm.completeDialog(confirmed: false),
                icon: const Icon(Icons.cancel, size: 20),
                label: const Text('Скасувати'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.textPrimary.withValues(
                    alpha: palette.isDark ? 0.18 : 0.08,
                  ),
                  foregroundColor: palette.textPrimary,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  side: BorderSide(
                    color: palette.cardBorder.withValues(alpha: 0.65),
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('frequencySaveButton'),
                onPressed: () => vm.completeDialog(confirmed: true),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('Зберегти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(fontSize: 13),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioRow(
    BuildContext context,
    FrequencyType value,
    Widget child,
  ) {
    final vm = context.watch<FrequencyDialogViewModel>();
    final palette = appAlertPaletteOf(context);
    return GestureDetector(
      onTap: () =>
          context.read<FrequencyDialogViewModel>().setFrequencyType(value),
      child: Row(
        children: [
          Radio<FrequencyType>(
            value: value,
            groupValue: vm.selectedType,
            onChanged: (val) =>
                context.read<FrequencyDialogViewModel>().setFrequencyType(val!),
            activeColor: palette.primary,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: palette.textPrimary),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
