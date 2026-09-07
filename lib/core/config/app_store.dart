/// Public store identifiers shared by Settings “Rate us” and the upgrader prompt.
abstract final class AppStoreIds {
  static const androidPackageName = 'com.set.principles';
  static const appStoreId = '6503646940';
  static const aboutSite = 'https://principles.top';

  static Uri playStoreListing() => Uri.parse(
    'https://play.google.com/store/apps/details?id=$androidPackageName',
  );

  static Uri appStoreListing({bool writeReview = false}) {
    final review = writeReview ? '?action=write-review' : '';
    return Uri.parse('https://apps.apple.com/app/id$appStoreId$review');
  }
}
