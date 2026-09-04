import 'package:flutter/material.dart';

import 'themed_lottie.dart';

/// Centered themed Lottie used while list / detail data is loading.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 96,
    this.padding = EdgeInsets.zero,
  });

  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ThemedLottie(
          assetPath: 'assets/lottie/loading.json',
          width: size,
          height: size,
        ),
      ),
    );
  }
}
