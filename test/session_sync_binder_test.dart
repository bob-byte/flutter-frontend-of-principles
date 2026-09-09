import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/launch_data_loader.dart';
import 'package:principles_app/core/road_guide/main_shell_controller.dart';
import 'package:principles_app/core/road_guide/road_guide_controller.dart';
import 'package:principles_app/core/sync/session_sync_binder.dart';
import 'package:principles_app/core/sync/sync_run_result.dart';
import 'package:principles_app/core/sync/sync_trigger.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLoader extends Fake implements LaunchDataLoader {
  final skipFlags = <bool>[];

  @override
  Future<SyncRunResult> syncAndHydrate(
    SyncTrigger trigger, {
    bool skipIfRecent = false,
  }) async {
    skipFlags.add(skipIfRecent);
    return const SyncRunResult(status: SyncRunStatus.skippedThrottled);
  }
}

class _FakeUserService extends Fake implements UserService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('resume catch-up is throttled after a permission-sheet pause', (
    tester,
  ) async {
    final loader = _FakeLoader();
    await tester.pumpWidget(
      Provider<LaunchDataLoader>.value(
        value: loader,
        child: const SessionSyncBinder(
          resumeAfter: Duration.zero,
          child: SizedBox.shrink(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(loader.skipFlags, [true]);
  });

  testWidgets('resume catch-up is skipped while the road guide is active', (
    tester,
  ) async {
    final loader = _FakeLoader();
    final guide = RoadGuideController(
      userService: _FakeUserService(),
      shell: MainShellController(),
    );
    final started = guide.start(markAsReplay: true);
    await tester.pump(const Duration(milliseconds: 300));
    await started;
    expect(guide.isActive, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LaunchDataLoader>.value(value: loader),
          ChangeNotifierProvider<RoadGuideController>.value(value: guide),
        ],
        child: const SessionSyncBinder(
          resumeAfter: Duration.zero,
          child: SizedBox.shrink(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(loader.skipFlags, isEmpty);
  });
}
