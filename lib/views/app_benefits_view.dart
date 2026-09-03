import 'package:flutter/material.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_controller.dart';
import '../viewmodels/app_benefits_viewmodel.dart';
import '../widgets/themed_lottie.dart';
import '../widgets/ui_theme_switcher.dart';

import 'startup_view.dart';

class AppBenefitsView extends StatefulWidget {
  const AppBenefitsView({super.key});

  static const routeName = '/app-benefits';

  @override
  State<AppBenefitsView> createState() => _AppBenefitsViewState();
}

class _AppBenefitsViewState extends State<AppBenefitsView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const double _navButtonSize = 50;
  static const double _navBarPadding = 20;
  static const double _navButtonGap = 12;

  double _nextButtonWidth({
    required double maxWidth,
    required bool isLastPage,
    required bool isFirstPage,
  }) {
    if (!isLastPage) return _navButtonSize;
    final reservedForPrev = isFirstPage ? 0.0 : _navButtonSize + _navButtonGap;
    return maxWidth - _navBarPadding - reservedForPrev;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<AppBenefitsViewModel>();
    final slides = vm.getSlides(l10n);

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final animationDuration = Duration(milliseconds: isIOS ? 1000 : 500);
    final palette = context.watch<ThemeController>().palette;
    final primary = palette.primary;

    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: AppThemeSwitcher(),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: vm.setCurrentPage,
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      return _AppBenefitSlide(
                        animationAssetPath: slide.animationAssetPath,
                        title: slide.title,
                        description: slide.description,
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Stack(
                      children: [
                        if (!vm.isLastPage)
                          Align(
                            alignment: Alignment.center,
                            child: IgnorePointer(
                              child: _DotsIndicator(
                                itemCount: slides.length,
                                currentIndex: vm.currentPage,
                                activeColor: primary,
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          child: AnimatedContainer(
                            key: const Key('appBenefitsNextContainer'),
                            duration: animationDuration,
                            curve: Curves.easeOut,
                            width: _nextButtonWidth(
                              maxWidth: constraints.maxWidth,
                              isLastPage: vm.isLastPage,
                              isFirstPage: vm.isFirstPage,
                            ),
                            height: 50,
                            child: ElevatedButton(
                              key: const Key('appBenefitsNextButton'),
                              onPressed: () async {
                                if (!vm.isLastPage) {
                                  await _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                  return;
                                }

                                final action = await vm
                                    .navigateToNextViewAction();
                                if (!context.mounted) return;
                                if (action ==
                                    AppBenefitsNavigationAction.goBack) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    StartupView.routeName,
                                    (_) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: palette.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                minimumSize: const Size(50, 50),
                              ),
                              child: Text(
                                vm.isLastPage ? l10n.ahead : '>',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!vm.isFirstPage)
                          Positioned(
                            left: 0,
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: ElevatedButton(
                                key: const Key('appBenefitsPrevButton'),
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: palette.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(50, 50),
                                ),
                                child: const Text(
                                  '<',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppBenefitSlide extends StatelessWidget {
  const _AppBenefitSlide({
    required this.animationAssetPath,
    required this.title,
    required this.description,
  });

  final String animationAssetPath;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ThemedLottieHalo(
            child: ThemedLottie(
              assetPath: animationAssetPath,
              width: 160,
              height: 160,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 6,
            style: TextStyle(
              fontSize: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.itemCount,
    required this.currentIndex,
    required this.activeColor,
  });

  final int itemCount;
  final int currentIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(itemCount, (index) {
        final isActive = index == currentIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : const Color(0xFF555555),
          ),
        );
      }),
    );
  }
}
