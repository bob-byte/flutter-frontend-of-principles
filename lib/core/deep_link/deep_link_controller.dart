import 'package:flutter/foundation.dart';

import 'deep_link_action.dart';
import 'notification_payload.dart';

/// Queues one pending deep link until [MainShell] (or another consumer) is ready.
class DeepLinkController extends ChangeNotifier {
  DeepLinkAction? _pending;

  DeepLinkAction? get pending => _pending;

  void enqueue(DeepLinkAction action) {
    if (action.isEmpty) return;
    _pending = action;
    notifyListeners();
  }

  void enqueueFromNotificationPayload(String? payload) {
    final action = parseNotificationPayload(payload);
    if (action == null) return;
    enqueue(action);
  }

  DeepLinkAction? takePending() {
    final action = _pending;
    _pending = null;
    return action;
  }
}
