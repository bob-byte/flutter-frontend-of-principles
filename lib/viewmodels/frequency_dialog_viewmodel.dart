import 'package:flutter/material.dart';
import '../../models/frequency_config.dart';
import '../../services/dialog_service.dart';

class FrequencyDialogViewModel extends ChangeNotifier {
  final DialogService _dialogService = DialogService();
  
  FrequencyType _selectedType = FrequencyType.daily;
  FrequencyType get selectedType => _selectedType;

  final TextEditingController daysController = TextEditingController(text: '3');
  final TextEditingController timesController = TextEditingController(text: '3');
  
  PeriodType _selectedPeriod = PeriodType.week;
  PeriodType get selectedPeriod => _selectedPeriod;

  void init(FrequencyConfig initialConfig) {
    _selectedType = initialConfig.type;
    
    if (initialConfig.type == FrequencyType.everyXDays) {
      daysController.text = (initialConfig.interval ?? 3).toString();
    } else if (initialConfig.type == FrequencyType.timesPerPeriod) {
      timesController.text = (initialConfig.interval ?? 3).toString();
      _selectedPeriod = initialConfig.period ?? PeriodType.week;
    }
  }

  void setFrequencyType(FrequencyType type) {
    if (_selectedType != type) {
      _selectedType = type;
      notifyListeners();
    }
  }

  void setPeriodType(PeriodType period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      _selectedType = FrequencyType.timesPerPeriod;
      notifyListeners();
    }
  }

  void completeDialog({required bool confirmed}) {
    if (!confirmed) {
      _dialogService.completeDialog(DialogResponse(confirmed: false));
      return;
    }

    FrequencyConfig result;
    if (_selectedType == FrequencyType.everyXDays) {
      result = FrequencyConfig(
        type: FrequencyType.everyXDays,
        interval: int.tryParse(daysController.text) ?? 1,
      );
    } else if (_selectedType == FrequencyType.timesPerPeriod) {
      result = FrequencyConfig(
        type: FrequencyType.timesPerPeriod,
        interval: int.tryParse(timesController.text) ?? 1,
        period: _selectedPeriod,
      );
    } else {
      result = const FrequencyConfig(type: FrequencyType.daily);
    }

    _dialogService.completeDialog(DialogResponse(confirmed: true, data: result));
  }

  @override
  void dispose() {
    daysController.dispose();
    timesController.dispose();
    super.dispose();
  }
}
