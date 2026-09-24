import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/widgets/lazy_shell_tab_stack.dart';

void main() {
  testWidgets('mounts tabs on first visit and keeps them alive', (
    tester,
  ) async {
    var index = 2;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                Expanded(
                  child: LazyShellTabStack(
                    index: index,
                    itemCount: 5,
                    initialMountedIndexes: const {2},
                    disposeWhenInactive: const {4},
                    builder: (context, i, isActive) {
                      return Text('tab-$i-active-$isActive');
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 0),
                  child: const Text('to-0'),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 2),
                  child: const Text('to-2'),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('tab-2-active-true'), findsOneWidget);
    expect(find.textContaining('tab-0', skipOffstage: false), findsNothing);
    expect(find.textContaining('tab-1', skipOffstage: false), findsNothing);

    await tester.tap(find.text('to-0'));
    await tester.pump();

    expect(find.text('tab-0-active-true'), findsOneWidget);
    expect(
      find.text('tab-2-active-false', skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('to-2'));
    await tester.pump();

    expect(
      find.text('tab-0-active-false', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('tab-2-active-true'), findsOneWidget);
  });

  testWidgets('disposes disposeWhenInactive tab when leaving', (tester) async {
    var index = 2;
    var settingsMounts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                Expanded(
                  child: LazyShellTabStack(
                    index: index,
                    itemCount: 5,
                    initialMountedIndexes: const {2},
                    disposeWhenInactive: const {4},
                    builder: (context, i, isActive) {
                      if (i == 4) {
                        return _CountingSettings(
                          onInit: () => settingsMounts++,
                        );
                      }
                      return Text('tab-$i');
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 4),
                  child: const Text('to-settings'),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 2),
                  child: const Text('to-tasks'),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(settingsMounts, 0);
    expect(find.text('settings', skipOffstage: false), findsNothing);

    await tester.tap(find.text('to-settings'));
    await tester.pump();
    expect(settingsMounts, 1);
    expect(find.text('settings'), findsOneWidget);

    await tester.tap(find.text('to-tasks'));
    await tester.pump();
    expect(find.text('settings', skipOffstage: false), findsNothing);

    await tester.tap(find.text('to-settings'));
    await tester.pump();
    expect(settingsMounts, 2);
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('TickerMode disables inactive keep-alive tabs', (tester) async {
    var index = 2;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                Expanded(
                  child: LazyShellTabStack(
                    index: index,
                    itemCount: 3,
                    initialMountedIndexes: const {2},
                    builder: (context, i, isActive) {
                      return Text('tab-$i');
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 0),
                  child: const Text('to-0'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('to-0'));
    await tester.pump();

    final inactive = tester.element(
      find.text('tab-2', skipOffstage: false),
    );
    expect(TickerMode.of(inactive), isFalse);
    final active = tester.element(find.text('tab-0'));
    expect(TickerMode.of(active), isTrue);
  });
}

class _CountingSettings extends StatefulWidget {
  const _CountingSettings({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountingSettings> createState() => _CountingSettingsState();
}

class _CountingSettingsState extends State<_CountingSettings> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Text('settings');
}
