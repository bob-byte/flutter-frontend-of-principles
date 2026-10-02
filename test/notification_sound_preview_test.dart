import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/app_notification_sound.dart';
import 'package:principles_app/services/notification_sound_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await NotificationSoundPreview.instance.dispose();
  });

  test('preview is a no-op under TestWidgetsFlutterBinding', () async {
    // Must not throw or touch the audioplayers platform channel in tests.
    await NotificationSoundPreview.instance.play(AppNotificationSound.chime);
    await NotificationSoundPreview.instance.play(AppNotificationSound.system);
  });
}
