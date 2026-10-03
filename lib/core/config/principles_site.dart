import '../theme/task_theme_palette.dart';
import 'app_store.dart';

/// Builds https://principles.top URLs with the app UI theme so the site can sync.
abstract final class PrinciplesSite {
  static const _origin = AppStoreIds.aboutSite;

  static Uri uri({String path = '/', required TasksUiTheme theme}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$_origin$normalized',
    ).replace(queryParameters: {'theme': theme.siteThemeId});
  }

  static Uri home(TasksUiTheme theme) => uri(theme: theme);

  static Uri privacyPolicy(TasksUiTheme theme) =>
      uri(path: '/privacypolicy', theme: theme);

  static Uri userAgreement(TasksUiTheme theme) =>
      uri(path: '/useragreement', theme: theme);
}
