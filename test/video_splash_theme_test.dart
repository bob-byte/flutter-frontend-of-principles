import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/views/video_splash_view.dart';

void main() {
  test('splash video follows orange vs blue theme on every palette', () {
    expect(
      TasksUiTheme.darkOrange.splashVideoAsset,
      'assets/splash/epic_start_orange.mp4',
    );
    expect(
      TasksUiTheme.lightOrange.splashVideoAsset,
      'assets/splash/epic_start_orange.mp4',
    );
    expect(
      TasksUiTheme.darkBlue.splashVideoAsset,
      'assets/splash/epic_start_blue.mp4',
    );
    expect(
      TasksUiTheme.lightBlue.splashVideoAsset,
      'assets/splash/epic_start_blue.mp4',
    );
    expect(TasksUiTheme.splashAudioAsset, 'assets/splash/epic_start.wav');
  });

  test('portrait splash zooms in without cropping the wordmark', () {
    final zoom = splashVideoZoom(
      viewport: const Size(390, 844),
      video: const Size(1920, 1080),
    );
    expect(zoom, closeTo(1 / kSplashVisibleWidthFraction, 0.01));
    expect(zoom, greaterThan(1.8));
  });

  test('16:9 landscape splash does not crop the frame', () {
    expect(
      splashVideoZoom(
        viewport: const Size(1920, 1080),
        video: const Size(1920, 1080),
      ),
      1,
    );
  });

  test('cold-start lifecycle burst does not skip epic_start', () {
    final now = DateTime(2026, 9, 3, 22, 30);
    expect(
      shouldFinishSplashOnResume(
        videoVisible: true,
        now: now,
        playedAt: now.subtract(const Duration(milliseconds: 50)),
        backgroundedAt: now.subtract(const Duration(milliseconds: 20)),
      ),
      isFalse,
    );
    expect(
      shouldFinishSplashOnResume(
        videoVisible: true,
        now: now,
        playedAt: now,
        backgroundedAt: now,
      ),
      isFalse,
    );
    expect(
      shouldFinishSplashOnResume(
        videoVisible: false,
        now: now,
        playedAt: now.subtract(const Duration(seconds: 1)),
        backgroundedAt: now.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });

  test('real resume after the clip started skips the remaining splash', () {
    final now = DateTime(2026, 9, 3, 22, 30);
    expect(
      shouldFinishSplashOnResume(
        videoVisible: true,
        now: now,
        playedAt: now.subtract(const Duration(seconds: 2)),
        backgroundedAt: now.subtract(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );
  });
}
