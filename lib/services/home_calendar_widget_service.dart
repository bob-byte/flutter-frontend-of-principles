import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../core/home_widget/home_calendar_constants.dart';
import '../core/utils/date_helpers.dart';
import '../models/home_calendar_snapshot.dart';

class HomeCalendarWidgetService {
  const HomeCalendarWidgetService();

  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(HomeCalendarWidgetConfig.appGroupId);
    } on MissingPluginException {
      // Tests / unsupported embeds.
    } catch (e) {
      debugPrint('Home calendar widget init failed: $e');
    }
  }

  Future<void> publish(HomeCalendarSnapshot snapshot) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(HomeCalendarWidgetConfig.appGroupId);
      await HomeWidget.saveWidgetData<String>(
        HomeCalendarWidgetConfig.snapshotKey,
        jsonEncode(snapshot.toJson()),
      );
      // One WidgetKit kind on Apple; three App Widget providers on Android.
      // Android-only updateWidget calls fail on iOS (requires iOSName/name).
      final updates = <Future<bool?>>[
        HomeWidget.updateWidget(
          qualifiedAndroidName: HomeCalendarWidgetConfig.androidMonthProvider,
          iOSName: HomeCalendarWidgetConfig.iosWidgetKind,
        ),
      ];
      if (defaultTargetPlatform == TargetPlatform.android) {
        updates.addAll([
          HomeWidget.updateWidget(
            qualifiedAndroidName: HomeCalendarWidgetConfig.androidWeekProvider,
          ),
          HomeWidget.updateWidget(
            qualifiedAndroidName: HomeCalendarWidgetConfig.androidTodayProvider,
          ),
        ]);
      }
      await Future.wait(updates);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _scheduleMidnightRefresh();
      }
    } on MissingPluginException {
      // Tests / unsupported embeds.
    } catch (e) {
      debugPrint('Home calendar widget publish failed: $e');
    }
  }

  Future<void> _scheduleMidnightRefresh() async {
    final next = dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1, minutes: 1));
    for (final provider in [
      HomeCalendarWidgetConfig.androidMonthProvider,
      HomeCalendarWidgetConfig.androidWeekProvider,
      HomeCalendarWidgetConfig.androidTodayProvider,
    ]) {
      try {
        await HomeWidget.scheduleWidgetUpdates([
          next,
        ], qualifiedAndroidName: provider);
      } catch (_) {
        // No instance of this size yet, or exact-alarm denied.
      }
    }
  }
}
