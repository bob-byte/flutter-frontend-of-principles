import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_benefits_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<AppBenefitsViewModel>();
    final slides = vm.getSlides(l10n);

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final animationDuration = Duration(milliseconds: isIOS ? 1000 : 500);
    const primaryBlue = Color(0xFF3A78EA);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
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
                        if (!vm.isFirstPage)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
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
                        Align(
                          alignment: Alignment.center,
                          child: _DotsIndicator(
                            itemCount: slides.length,
                            currentIndex: vm.currentPage,
                            activeColor: primaryBlue,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: animationDuration,
                            curve: Curves.easeOut,
                            width: vm.isLastPage ? constraints.maxWidth - 80 : 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!vm.isLastPage) {
                                  await _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                  return;
                                }

                                final action = await vm.navigateToNextViewAction();
                                if (!context.mounted) return;
                                if (action == AppBenefitsNavigationAction.goBack) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    StartupView.routeName,
                                    (_) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: EdgeInsets.zero,
                                elevation: 0,
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
          Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.6,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xCA3D7FFF),
                  Color(0x4700E0FF),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.1, 0.3, 0.5, 0.8, 0.9],
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Lottie.asset(
                  animationAssetPath,
                  repeat: true,
                  animate: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: Color(0xFF222222),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 6,
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF555555),
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
