import 'package:flutter_test/flutter_test.dart';

import 'package:principles_app/models/ai_task_draft.dart';
import 'package:principles_app/models/task_priority.dart';

void main() {
  test('AiTaskDraft.fromJson maps OpenAI JSON fields', () {
    final draft = AiTaskDraft.fromJson({
      'title': 'Купити продукти',
      'description': 'Овочі, фрукти, ягоди',
      'priority': 'high',
      'theme': "Здоров'я",
      'dueDate': '2026-07-26',
    });

    expect(draft.title, 'Купити продукти');
    expect(draft.description, 'Овочі, фрукти, ягоди');
    expect(draft.priority, TaskPriority.high);
    expect(draft.theme, "Здоров'я");
    expect(draft.hasDueDate, isTrue);
    expect(draft.dueDate, DateTime(2026, 7, 26));
    expect(draft.allDay, isTrue);
    expect(draft.reminders, isEmpty);
    expect(draft.subtasks, isEmpty);
  });

  test('AiTaskDraft.fromJson keeps time, reminders, and subtasks', () {
    final draft = AiTaskDraft.fromJson({
      'title': 'Team sync',
      'description': '',
      'priority': 'medium',
      'theme': null,
      'dueDate': '2026-09-12T18:30',
      'allDay': false,
      'reminders': [
        30,
        0,
        {'offsetMinutes': 60},
      ],
      'subtasks': [
        'Prepare agenda',
        {'title': 'Share notes'},
        {'name': 'Book room'},
      ],
    });

    expect(draft.dueDate, DateTime(2026, 9, 12, 18, 30));
    expect(draft.allDay, isFalse);
    expect(draft.reminders.map((r) => r.offsetMinutes), [0, 30, 60]);
    expect(draft.subtasks.map((s) => s.title), [
      'Prepare agenda',
      'Share notes',
      'Book room',
    ]);
  });

  test('AiTaskDraft.fromJson strips timezone suffix as local wall clock', () {
    final draft = AiTaskDraft.fromJson({
      'title': 'Call',
      'dueDate': '2026-09-12T15:00:00Z',
    });

    expect(draft.dueDate, DateTime(2026, 9, 12, 15, 0));
    expect(draft.allDay, isFalse);
  });

  test('AiTaskDraft.fromJson tolerates null optional fields', () {
    final draft = AiTaskDraft.fromJson({
      'title': 'Полити квіти',
      'description': '',
      'priority': null,
      'theme': null,
      'dueDate': null,
    });

    expect(draft.title, 'Полити квіти');
    expect(draft.description, isEmpty);
    expect(draft.priority, isNull);
    expect(draft.theme, isNull);
    expect(draft.hasDueDate, isFalse);
    expect(draft.reminders, isEmpty);
    expect(draft.subtasks, isEmpty);
  });
}
