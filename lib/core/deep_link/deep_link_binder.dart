import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/reminder_service.dart';
import 'deep_link_controller.dart';

/// Wires local-notification taps (foreground/background/cold start) into
/// [DeepLinkController].
class DeepLinkBinder extends StatefulWidget {
  const DeepLinkBinder({super.key, required this.child});

  final Widget child;

  @override
  State<DeepLinkBinder> createState() => _DeepLinkBinderState();
}

class _DeepLinkBinderState extends State<DeepLinkBinder> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    ReminderService.onNotificationOpened = _onPayload;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_consumeColdStart());
    });
  }

  @override
  void dispose() {
    if (identical(ReminderService.onNotificationOpened, _onPayload)) {
      ReminderService.onNotificationOpened = null;
    }
    super.dispose();
  }

  void _onPayload(String? payload) {
    if (!mounted) return;
    context.read<DeepLinkController>().enqueueFromNotificationPayload(payload);
  }

  Future<void> _consumeColdStart() async {
    if (!mounted || kIsWeb) return;
    final payload = await ReminderService.consumeAppLaunchNotificationPayload();
    if (!mounted || payload == null) return;
    context.read<DeepLinkController>().enqueueFromNotificationPayload(payload);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
