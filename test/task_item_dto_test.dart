import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/sync/sync_bootstrap_snapshot.dart';
import 'package:principles_app/models/task_item_dto.dart';

void main() {
  test('parses camelCase task JSON', () {
    final dto = TaskItemDto.fromJson({
      'id': 12,
      'name': 'Call mom',
      'notes': 'evening',
      'date': '2026-09-03',
      'time': '18:30:00',
      'isCompleted': true,
    });

    expect(dto.id, 12);
    expect(dto.name, 'Call mom');
    expect(dto.date, '2026-09-03');
    expect(dto.time, '18:30:00');
    expect(dto.isCompleted, isTrue);
  });

  test('parses DateOnly and TimeOnly object JSON', () {
    final dto = TaskItemDto.fromJson({
      'Id': 4,
      'Name': 'Stretch',
      'Date': {'year': 2026, 'month': 9, 'day': 3},
      'Time': {'hour': 7, 'minute': 15, 'second': 0},
      'IsCompleted': false,
    });

    expect(dto.id, 4);
    expect(dto.name, 'Stretch');
    expect(dto.date, '2026-09-03');
    expect(dto.time, '07:15:00');
    expect(dto.isCompleted, isFalse);
  });

  test('bootstrap snapshot keeps goals when a task payload is malformed', () {
    final snapshot = SyncBootstrapSnapshot.fromJson({
      'goals': [
        {'id': 1, 'name': 'Health'},
      ],
      'tasks': [
        {'id': 2, 'name': 'Walk'},
        'not-a-task',
      ],
    });

    expect(snapshot.goals, hasLength(1));
    expect(snapshot.goals.single.name, 'Health');
    expect(snapshot.tasks, hasLength(1));
    expect(snapshot.tasks.single.name, 'Walk');
  });

  test('round-trips schedule fields', () {
    final dto = TaskItemDto.fromJson({
      'id': 9,
      'name': 'Therapy',
      'date': '2026-09-07',
      'time': '11:30:00',
      'endDate': '2026-09-07',
      'endTime': '12:15:00',
      'allDay': false,
      'constantReminder': true,
      'reminders': [
        {'offsetMinutes': 0},
        {'offsetMinutes': 1440, 'notificationRequestId': 55},
      ],
      'repeat': {
        'preset': 'weekly',
        'interval': 1,
        'unit': 'week',
        'weekdays': [1],
        'anchor': 'dueDates',
      },
    });

    expect(dto.reminders, hasLength(2));
    expect(dto.reminders.last.offsetMinutes, 1440);
    expect(dto.repeat?.preset.name, 'weekly');

    final task = dto.toTask();
    expect(task.dueDate, DateTime(2026, 9, 7, 11, 30));
    expect(task.endDate, DateTime(2026, 9, 7, 12, 15));
    expect(task.constantReminder, isTrue);
    expect(task.reminders.map((e) => e.offsetMinutes), [0, 1440]);

    final encoded = TaskItemDto.fromTask(task).toJson();
    expect(encoded['constantReminder'], isTrue);
    expect((encoded['reminders'] as List), hasLength(2));
    expect((encoded['repeat'] as Map)['preset'], 'weekly');
  });
}
