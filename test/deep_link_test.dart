import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/deep_link/deep_link_action.dart';
import 'package:principles_app/core/deep_link/deep_link_controller.dart';
import 'package:principles_app/core/deep_link/notification_payload.dart';
import 'package:principles_app/core/home_widget/home_widget_link.dart';

void main() {
  group('parseNotificationPayload', () {
    test('parses task and constant task payloads', () {
      expect(parseNotificationPayload('task:42')?.taskId, '42');
      expect(
        parseNotificationPayload('task_constant:99')?.kind,
        DeepLinkKind.openTask,
      );
      expect(parseNotificationPayload('task_constant:99')?.taskId, '99');
    });

    test('parses habit and constant habit payloads', () {
      final habit = parseNotificationPayload('habit:7');
      expect(habit?.kind, DeepLinkKind.openHabitDetail);
      expect(habit?.habitId, 7);

      final constant = parseNotificationPayload('habit_constant:12');
      expect(constant?.kind, DeepLinkKind.openHabitDetail);
      expect(constant?.habitId, 12);
    });

    test('parses habits report payload as Tasks today', () {
      final action = parseNotificationPayload('habits_report');
      expect(action?.kind, DeepLinkKind.openTasksTab);
      expect(action?.openToday, isTrue);
    });

    test('rejects empty or unknown payloads', () {
      expect(parseNotificationPayload(null), isNull);
      expect(parseNotificationPayload(''), isNull);
      expect(parseNotificationPayload('task:'), isNull);
      expect(parseNotificationPayload('habit:x'), isNull);
      expect(parseNotificationPayload('other'), isNull);
    });
  });

  group('DeepLinkController', () {
    test('queues and replaces pending actions', () {
      final controller = DeepLinkController();
      controller.enqueue(const DeepLinkAction.openHabitsTab());
      expect(controller.pending?.kind, DeepLinkKind.openHabitsTab);

      controller.enqueue(const DeepLinkAction.openTask('1'));
      expect(controller.pending?.taskId, '1');

      final taken = controller.takePending();
      expect(taken?.taskId, '1');
      expect(controller.pending, isNull);
    });

    test('enqueues from notification payload', () {
      final controller = DeepLinkController();
      controller.enqueueFromNotificationPayload('habit:3');
      expect(controller.takePending()?.habitId, 3);
    });

    test('wraps home widget launch actions', () {
      final action = DeepLinkAction.homeWidget(
        const HomeWidgetLaunchAction(openToday: true, openCreate: true),
      );
      expect(action.kind, DeepLinkKind.homeWidget);
      expect(action.openToday, isTrue);
      expect(action.openCreate, isTrue);
    });
  });
}
