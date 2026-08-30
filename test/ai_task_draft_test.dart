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
  });
}
