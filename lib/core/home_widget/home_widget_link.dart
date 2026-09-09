import '../utils/date_helpers.dart';
import 'home_calendar_constants.dart';

class HomeWidgetLaunchAction {
  const HomeWidgetLaunchAction({
    this.day,
    this.openCreate = false,
    this.openToday = false,
  });

  final DateTime? day;
  final bool openCreate;
  final bool openToday;

  bool get isEmpty => day == null && !openCreate && !openToday;
}

HomeWidgetLaunchAction? parseHomeWidgetLaunchUri(Uri? uri) {
  if (uri == null) return null;
  final isWidget =
      (uri.scheme == HomeCalendarWidgetConfig.urlScheme &&
          uri.host == HomeCalendarWidgetConfig.urlHost) ||
      uri.host == HomeCalendarWidgetConfig.urlHost ||
      uri.pathSegments.contains(HomeCalendarWidgetConfig.urlHost);
  if (!isWidget && uri.scheme != HomeCalendarWidgetConfig.urlScheme) {
    return null;
  }

  final action =
      uri.queryParameters['action'] ?? HomeCalendarWidgetAction.today;
  final date = homeCalendarParseDateKey(uri.queryParameters['date']);

  return switch (action) {
    HomeCalendarWidgetAction.create => HomeWidgetLaunchAction(
      day: date == null ? null : dateOnly(date),
      openCreate: true,
    ),
    HomeCalendarWidgetAction.day => HomeWidgetLaunchAction(
      day: date == null ? null : dateOnly(date),
    ),
    HomeCalendarWidgetAction.today => const HomeWidgetLaunchAction(
      openToday: true,
    ),
    _ => null,
  };
}
