import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/task_theme_palette.dart';
import '../core/theme/theme_controller.dart';

/// App mark that follows the active orange/blue theme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  static TasksUiTheme themeOf(BuildContext context) {
    try {
      return Provider.of<ThemeController>(context, listen: true).uiTheme;
    } on ProviderNotFoundException {
      return TasksUiTheme.darkOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeOf(context);

    return Image.asset(
      theme.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Principles',
    );
  }
}
