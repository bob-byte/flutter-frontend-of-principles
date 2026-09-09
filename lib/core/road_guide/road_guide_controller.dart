import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/user_service.dart';
import 'main_shell_controller.dart';
import 'road_guide_steps.dart';

/// Spotlight road guide: once per device auto-play, replayable from Settings.
class RoadGuideController extends ChangeNotifier {
  RoadGuideController({
    required UserService userService,
    required MainShellController shell,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _userService = userService,
       _shell = shell,
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const prefsKey = 'road_guide_completed_on_device_v1';

  final UserService _userService;
  final MainShellController _shell;
  final Future<SharedPreferences> Function() _prefsFactory;

  final keys = RoadGuideKeys();
  late final List<RoadGuideStep> steps = keys.buildSteps();

  bool _isActive = false;
  bool _showDemoData = false;
  int _stepIndex = 0;
  bool _completedOnDevice = false;
  bool _loaded = false;

  bool get isActive => _isActive;
  bool get showDemoData => _showDemoData;
  bool get isLoaded => _loaded;
  bool get completedOnDevice => _completedOnDevice;
  int get stepIndex => _stepIndex;
  int get totalSteps => steps.length;
  bool get isLastStep => _stepIndex >= steps.length - 1;
  bool get isFirstStep => _stepIndex <= 0;

  RoadGuideStep? get currentStep {
    if (!_isActive || _stepIndex < 0 || _stepIndex >= steps.length) {
      return null;
    }
    return steps[_stepIndex];
  }

  Future<void> loadDeviceFlag() async {
    final prefs = await _prefsFactory();
    _completedOnDevice = prefs.getBool(prefsKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Auto-start after first sign-in on this device.
  Future<void> maybeAutoStart() async {
    if (!_loaded) await loadDeviceFlag();
    if (_completedOnDevice || _isActive) return;
    await start(markAsReplay: false);
  }

  Future<void> start({bool markAsReplay = true}) async {
    if (_isActive) return;
    _stepIndex = 0;
    _showDemoData = true;
    _isActive = true;
    _applyEnsureTab(steps.first);
    notifyListeners();
    // Allow IndexedStack / demo tiles / tab bar to mount and lay out before
    // the overlay measures spotlight holes (auto-start after SyncGate is the
    // heavy case — shell just appeared).
    await Future<void>.delayed(const Duration(milliseconds: 280));
    notifyListeners();
    if (markAsReplay) {
      // Replay does not change completion flags until finished/skipped.
    }
  }

  Future<void> next() async {
    if (!_isActive) return;
    final step = currentStep;
    if (step == null) return;

    final switchTab = step.switchToTabOnNext;
    if (isLastStep) {
      await complete();
      return;
    }

    _stepIndex += 1;
    if (switchTab != null) {
      _shell.setIndex(switchTab);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    _applyEnsureTab(steps[_stepIndex]);
    notifyListeners();
    final waitMs = steps[_stepIndex].opensPushedRoute ? 520 : 60;
    await Future<void>.delayed(Duration(milliseconds: waitMs));
    notifyListeners();
  }

  Future<void> back() async {
    if (!_isActive || isFirstStep) return;
    _stepIndex -= 1;
    _applyEnsureTab(steps[_stepIndex]);
    notifyListeners();
    final waitMs = steps[_stepIndex].opensPushedRoute ? 520 : 60;
    await Future<void>.delayed(Duration(milliseconds: waitMs));
    notifyListeners();
  }

  Future<void> skip() => complete();

  Future<void> complete() async {
    if (!_isActive && _completedOnDevice) return;
    _isActive = false;
    _showDemoData = false;
    _stepIndex = 0;
    notifyListeners();

    _completedOnDevice = true;
    try {
      final prefs = await _prefsFactory();
      await prefs.setBool(prefsKey, true);
    } catch (e) {
      debugPrint('Road guide prefs save failed: $e');
    }

    try {
      await _userService.saveHasSeenRoadGuide(true);
    } catch (e) {
      debugPrint('Road guide profile save failed: $e');
    }
    notifyListeners();
  }

  void _applyEnsureTab(RoadGuideStep step) {
    final tab = step.ensureTabOnShow;
    if (tab != null) {
      _shell.setIndex(tab);
    }
  }
}
