import 'package:flutter_test/flutter_test.dart';

import 'package:principles_app/models/user.dart';

void main() {
  test('parses camelCase profile JSON from the API', () {
    final user = User.fromJson({
      'id': 12,
      'name': 'Ada',
      'mainSlogan': 'Keep going',
      'mission': 'Build tools',
      'email': 'ada@example.com',
      'gender': 1,
      'lastModified': '2026-09-03T07:00:00.000Z',
    });

    expect(user.id, 12);
    expect(user.name, 'Ada');
    expect(user.mainSlogan, 'Keep going');
    expect(user.mission, 'Build tools');
    expect(user.email, 'ada@example.com');
    expect(user.gender, 1);
    expect(user.lastModified, DateTime.utc(2026, 9, 3, 7));
  });

  test('parses PascalCase profile JSON from MAUI-style payloads', () {
    final user = User.fromJson({
      'Id': 4,
      'Name': 'Grace',
      'MainSlogan': 'Ship it',
      'Mission': 'Help people',
      'Email': 'grace@example.com',
      'Gender': 0,
    });

    expect(user.id, 4);
    expect(user.name, 'Grace');
    expect(user.mainSlogan, 'Ship it');
    expect(user.mission, 'Help people');
    expect(user.email, 'grace@example.com');
    expect(user.gender, 0);
  });
}
