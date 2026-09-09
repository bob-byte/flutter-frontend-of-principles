import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/reminder_service.dart';

/// Clears delivered (tray) notifications when the app starts or resumes.
///
/// Matches MAUI [App.OnStart] / [App.OnResume] →
/// `LocalNotificationCenter.Current.ClearAll()`.
class DeliveredNotificationClearer extends StatefulWidget {
  const DeliveredNotificationClearer({super.key, required this.child});

  final Widget child;

  @override
  State<DeliveredNotificationClearer> createState() =>
      _DeliveredNotificationClearerState();
}

class _DeliveredNotificationClearerState
    extends State<DeliveredNotificationClearer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _clear());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clear();
    }
  }

  void _clear() {
    if (!mounted) return;
    unawaited(context.read<ReminderService>().clearDeliveredLocally());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
