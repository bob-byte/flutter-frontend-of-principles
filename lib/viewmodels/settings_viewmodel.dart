import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/locale/locale_controller.dart';
import '../models/user.dart';
import '../services/settings_service.dart';
import '../services/user_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsService settingsService,
    required LocaleController localeController,
    required UserService userService,
  }) : _settingsService = settingsService,
       _localeController = localeController,
       _userService = userService;

  static final Uri _aboutUri = Uri.parse('https://principles.top');
  static final Uri _telegramUri = Uri.parse('https://t.me/principles_app');
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://principles.top/privacypolicy',
  );
  static final Uri _userAgreementUri = Uri.parse(
    'https://principles.top/useragreement',
  );
  static const contactEmailAddress = 'batsbohdan@gmail.com';
  static final Uri _contactEmailUri = Uri.parse('mailto:$contactEmailAddress');
  static const _androidPackageName = 'com.set.principles';
  static const _appStoreId = '6503646940';

  final SettingsService _settingsService;
  final LocaleController _localeController;
  final UserService _userService;

  User _user = User();
  bool _isLoadingProfile = false;
  bool _isSavingProfile = false;
  bool _isDeletingAccount = false;
  String? _profileError;

  Locale? get localeOverride => _localeController.localeOverride;

  User get user => _user;
  String get userName => _user.name ?? '';
  String get email => _user.email ?? '';
  String get mainSlogan => _user.mainSlogan ?? '';
  String get mission => _user.mission ?? '';
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isSavingProfile => _isSavingProfile;
  bool get isDeletingAccount => _isDeletingAccount;
  String? get profileError => _profileError;

  Future<void> load() async {
    await Future.wait([loadLocale(), loadProfile()]);
  }

  Future<void> loadLocale() async {
    final value = await _settingsService.getLocaleOverride();
    if (value == null) {
      _localeController.setLocaleOverride(null);
      return;
    }
    if (value == 'en' || value == 'uk') {
      _localeController.setLocaleOverride(Locale(value));
      return;
    }
    _localeController.setLocaleOverride(null);
  }

  Future<void> loadProfile() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      _user = await _userService.getCurrentUser();
    } catch (e) {
      _profileError = e.toString();
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    _localeController.setLocaleOverride(locale);
    await _settingsService.setLocaleOverride(locale?.languageCode);
    notifyListeners();
  }

  Future<bool> saveUserName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return Future.value(false);
    return _saveProfileField(
      () => _userService.saveUserName(trimmed),
      (user) => user.copyWith(name: trimmed),
    );
  }

  Future<bool> saveMainSlogan(String value) {
    final trimmed = value.trim();
    return _saveProfileField(
      () => _userService.saveMainSlogan(trimmed),
      (user) => user.copyWith(mainSlogan: trimmed),
    );
  }

  Future<bool> saveMission(String value) {
    final trimmed = value.trim();
    return _saveProfileField(
      () => _userService.saveMission(trimmed),
      (user) => user.copyWith(mission: trimmed),
    );
  }

  Future<void> clearProfile() async {
    await _userService.clearLocal();
    _user = User();
    notifyListeners();
  }

  Future<void> openAboutSite() {
    return launchUrl(_aboutUri, mode: LaunchMode.externalApplication);
  }

  Future<void> openTelegramChannel() {
    return launchUrl(_telegramUri, mode: LaunchMode.externalApplication);
  }

  Future<void> openPrivacyPolicy() {
    return launchUrl(_privacyPolicyUri, mode: LaunchMode.externalApplication);
  }

  Future<void> openUserAgreement() {
    return launchUrl(_userAgreementUri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openContactEmail() async {
    try {
      return await launchUrl(
        _contactEmailUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Cannot open contact email: $e');
      return false;
    }
  }

  Future<void> rateApp() async {
    final inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }
      await _openStoreListing(inAppReview);
    } catch (e) {
      debugPrint('Cannot request in-app review: $e');
      try {
        await launchUrl(_rateUri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        debugPrint('Cannot open store listing: $e2');
      }
    }
  }

  Future<void> shareApp(String message) async {
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (e) {
      debugPrint('Cannot share app: $e');
    }
  }

  Future<void> _openStoreListing(InAppReview inAppReview) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return inAppReview.openStoreListing(appStoreId: _appStoreId);
      default:
        return launchUrl(_rateUri, mode: LaunchMode.externalApplication);
    }
  }

  Uri get _rateUri {
    if (kIsWeb) return _aboutUri;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Uri.parse(
          'https://play.google.com/store/apps/details?id=$_androidPackageName',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Uri.parse(
          'https://apps.apple.com/app/id$_appStoreId?action=write-review',
        );
      default:
        return _aboutUri;
    }
  }

  Future<bool> deleteAccount() async {
    _isDeletingAccount = true;
    _profileError = null;
    notifyListeners();
    try {
      await _userService.deleteAccount();
      _user = User();
      return true;
    } catch (e) {
      _profileError = e.toString();
      return false;
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  Future<bool> _saveProfileField(
    Future<void> Function() persist,
    User Function(User user) update,
  ) async {
    _isSavingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      await persist();
      _user = update(_user);
      return true;
    } catch (e) {
      _profileError = e.toString();
      _user = update(_user);
      return false;
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }
}
