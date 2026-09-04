import 'package:flutter/foundation.dart';
import 'package:principles_app/l10n/app_localizations.dart';

import '../models/app_benefit.dart';
import '../services/auth_service.dart';

enum AppBenefitsNavigationAction { goBack, startupAbsolute }

class AppBenefitsSlideContent {
  const AppBenefitsSlideContent({
    required this.animationAssetPath,
    required this.title,
    required this.description,
  });

  final String animationAssetPath;
  final String title;
  final String description;
}

class AppBenefitsViewModel extends ChangeNotifier {
  AppBenefitsViewModel(
    this._authService, {
    Future<String?> Function()? tokenReader,
  }) : _tokenReader = tokenReader;

  final AuthService _authService;
  final Future<String?> Function()? _tokenReader;
  int _currentPage = 0;

  static const List<AppBenefit> _benefits = [
    AppBenefit(
      animationAssetPath: 'assets/lottie/transform_areas_carousel.json',
      titleKey: 'TransformAreasOfLifeTitle',
      descriptionKey: 'TransformAreasOfLifeDescription',
    ),
    AppBenefit(
      animationAssetPath: 'assets/lottie/chat_ai_carousel.json',
      titleKey: 'ChatWithHelperTitle',
      descriptionKey: 'ChatWithHelperDescription',
    ),
    AppBenefit(
      animationAssetPath: 'assets/lottie/group_habits_carousel.json',
      titleKey: 'GroupHabitsByGoalsTitle',
      descriptionKey: 'GroupHabitsByGoalsDescription',
    ),
    AppBenefit(
      animationAssetPath: 'assets/lottie/get_recommendations_carousel.json',
      titleKey: 'GetRecommendationsByAITitle',
      descriptionKey: 'GetRecommendationsByAIDescription',
    ),
    AppBenefit(
      animationAssetPath: 'assets/lottie/become_personality_carousel.json',
      titleKey: 'BecomeTruePersonalityTitle',
      descriptionKey: 'BecomeTruePersonalityDescription',
    ),
  ];

  List<AppBenefitsSlideContent> getSlides(AppLocalizations l10n) {
    return _benefits
        .map(
          (benefit) => AppBenefitsSlideContent(
            animationAssetPath: benefit.animationAssetPath,
            title: _resolveLocalizedKey(l10n, benefit.titleKey),
            description: _resolveLocalizedKey(l10n, benefit.descriptionKey),
          ),
        )
        .toList(growable: false);
  }

  int get currentPage => _currentPage;
  int get totalPages => _benefits.length;
  bool get isFirstPage => _currentPage == 0;
  bool get isLastPage => _currentPage == _benefits.length - 1;

  void setCurrentPage(int page) {
    if (page < 0 || page >= _benefits.length || page == _currentPage) {
      return;
    }
    _currentPage = page;
    notifyListeners();
  }

  Future<AppBenefitsNavigationAction> navigateToNextViewAction() async {
    final token = await (_tokenReader?.call() ?? _authService.getToken());
    final isLoggedIn = token != null && token.isNotEmpty;
    return isLoggedIn
        ? AppBenefitsNavigationAction.goBack
        : AppBenefitsNavigationAction.startupAbsolute;
  }

  /// First-run onboarding replaces `/`, so there is nothing to pop.
  /// Skip the token read in that case; a leftover session must not no-op.
  Future<AppBenefitsNavigationAction> resolveAheadAction({
    required bool canPop,
  }) async {
    if (!canPop) return AppBenefitsNavigationAction.startupAbsolute;
    return navigateToNextViewAction();
  }

  String _resolveLocalizedKey(AppLocalizations l10n, String key) {
    return switch (key) {
      'TransformAreasOfLifeTitle' => l10n.transformAreasOfLifeTitle,
      'TransformAreasOfLifeDescription' => l10n.transformAreasOfLifeDescription,
      'ChatWithHelperTitle' => l10n.chatWithHelperTitle,
      'ChatWithHelperDescription' => l10n.chatWithHelperDescription,
      'GroupHabitsByGoalsTitle' => l10n.groupHabitsByGoalsTitle,
      'GroupHabitsByGoalsDescription' => l10n.groupHabitsByGoalsDescription,
      'GetRecommendationsByAITitle' => l10n.getRecommendationsByAITitle,
      'GetRecommendationsByAIDescription' =>
        l10n.getRecommendationsByAIDescription,
      'BecomeTruePersonalityTitle' => l10n.becomeTruePersonalityTitle,
      'BecomeTruePersonalityDescription' =>
        l10n.becomeTruePersonalityDescription,
      _ => key,
    };
  }
}
