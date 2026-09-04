import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/frequency_config.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/viewmodels/frequency_dialog_viewmodel.dart';

void main() {
  late FrequencyDialogViewModel vm;

  setUp(() {
    vm = FrequencyDialogViewModel();
  });

  tearDown(() => vm.dispose());

  test('init loads everyXDays interval', () {
    vm.init(
      const FrequencyConfig(type: FrequencyType.everyXDays, interval: 5),
    );
    expect(vm.selectedType, FrequencyType.everyXDays);
    expect(vm.daysController.text, '5');
  });

  test('init loads timesPerPeriod interval and period', () {
    vm.init(
      const FrequencyConfig(
        type: FrequencyType.timesPerPeriod,
        interval: 4,
        period: PeriodType.month,
      ),
    );
    expect(vm.selectedType, FrequencyType.timesPerPeriod);
    expect(vm.timesController.text, '4');
    expect(vm.selectedPeriod, PeriodType.month);
  });

  test('setPeriodType selects timesPerPeriod', () {
    vm.setPeriodType(PeriodType.month);
    expect(vm.selectedType, FrequencyType.timesPerPeriod);
    expect(vm.selectedPeriod, PeriodType.month);
  });

  test('setFrequencyType updates selection', () {
    vm.setFrequencyType(FrequencyType.everyXDays);
    expect(vm.selectedType, FrequencyType.everyXDays);
  });

  testWidgets('completeDialog confirmed builds daily config', (tester) async {
    final captured = await _completeThroughDialog(tester, (vm) {
      vm.setFrequencyType(FrequencyType.daily);
      vm.completeDialog(confirmed: true);
    });

    expect(captured?.confirmed, isTrue);
    final config = captured!.data as FrequencyConfig;
    expect(config.type, FrequencyType.daily);
    expect(config.interval, isNull);
  });

  testWidgets('completeDialog confirmed builds everyXDays config', (
    tester,
  ) async {
    final captured = await _completeThroughDialog(tester, (vm) {
      vm.setFrequencyType(FrequencyType.everyXDays);
      vm.daysController.text = '7';
      vm.completeDialog(confirmed: true);
    });

    expect(captured?.confirmed, isTrue);
    final config = captured!.data as FrequencyConfig;
    expect(config.type, FrequencyType.everyXDays);
    expect(config.interval, 7);
  });

  testWidgets('completeDialog confirmed builds timesPerPeriod config', (
    tester,
  ) async {
    final captured = await _completeThroughDialog(tester, (vm) {
      vm.setPeriodType(PeriodType.month);
      vm.timesController.text = '4';
      vm.completeDialog(confirmed: true);
    });

    expect(captured?.confirmed, isTrue);
    final config = captured!.data as FrequencyConfig;
    expect(config.type, FrequencyType.timesPerPeriod);
    expect(config.interval, 4);
    expect(config.period, PeriodType.month);
  });

  testWidgets('completeDialog cancel returns unconfirmed', (tester) async {
    final captured = await _completeThroughDialog(tester, (vm) {
      vm.completeDialog(confirmed: false);
    });

    expect(captured?.confirmed, isFalse);
    expect(captured?.data, isNull);
  });
}

Future<DialogResponse?> _completeThroughDialog(
  WidgetTester tester,
  void Function(FrequencyDialogViewModel vm) act,
) async {
  final dialog = DialogService();
  DialogResponse? captured;
  final vm = FrequencyDialogViewModel();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: dialog.navigatorKey,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                captured = await showDialog<DialogResponse>(
                  context: context,
                  builder: (_) => const SizedBox.shrink(),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  act(vm);
  await tester.pumpAndSettle();
  vm.dispose();
  return captured;
}
