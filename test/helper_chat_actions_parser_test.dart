import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/helper/helper_chat_actions_parser.dart';
import 'package:principles_app/models/helper_chat_action.dart';

void main() {
  test('parseHelperChatActions strips trailer and reads items', () {
    const raw = '''
Try this habit tomorrow.

<<<ACTIONS>>>
[{"type":"habit","name":"Walk 20 min","reason":"Easy win","goalName":"Health"},{"type":"goal","name":"Run a 5k","reason":"Clear target"}]
<<<END>>>
''';

    final parsed = parseHelperChatActions(raw);

    expect(parsed.displayText.trim(), 'Try this habit tomorrow.');
    expect(parsed.actions, hasLength(2));
    expect(parsed.actions[0].type, HelperChatActionType.habit);
    expect(parsed.actions[0].title, 'Walk 20 min');
    expect(parsed.actions[0].goalName, 'Health');
    expect(parsed.actions[1].type, HelperChatActionType.goal);
    expect(parsed.actions[1].title, 'Run a 5k');
  });

  test('parseHelperChatActions hides incomplete trailer while streaming', () {
    const raw =
        'Here is a plan.\n\n<<<ACTIONS>>>\n[{"type":"task","title":"Buy';

    final parsed = parseHelperChatActions(raw, parseActions: false);

    expect(parsed.displayText.trim(), 'Here is a plan.');
    expect(parsed.actions, isEmpty);
  });

  test('helperChatDisplayText removes actions for copy/API', () {
    const raw =
        'Hello\n<<<ACTIONS>>>[{"type":"mission","text":"Serve others"}]<<<END>>>';

    expect(helperChatDisplayText(raw).trim(), 'Hello');
  });

  test('notes-only JSON populates notes, not reason', () {
    final action = HelperChatAction.fromJson({
      'type': 'goal',
      'name': 'Fitness',
      'notes': 'Gym 3x week',
    });

    expect(action.reason, isEmpty);
    expect(action.notes, 'Gym 3x week');
  });

  test('reason and notes stay distinct when both are present', () {
    final action = HelperChatAction.fromJson({
      'type': 'habit',
      'name': 'Walk',
      'reason': 'Easy win',
      'notes': 'Park loop',
    });

    expect(action.reason, 'Easy win');
    expect(action.notes, 'Park loop');
  });
}
