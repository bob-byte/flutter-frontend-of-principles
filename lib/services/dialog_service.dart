import 'package:flutter/material.dart';

enum DialogType { frequencyConfig, addEditGoal }
enum BottomSheetType { goalSelection, archive, areaSelection }

class DialogResponse {
  final bool confirmed;
  final dynamic data;

  DialogResponse({
    this.confirmed = false,
    this.data,
  });
}
class SheetResponse {
  final bool confirmed;
  final dynamic data;

  SheetResponse({
    this.confirmed = false,
    this.data,
  });
}
class DialogService {
  static final DialogService _instance = DialogService._internal();
  factory DialogService() => _instance;
  DialogService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // A map to register dialog builders
  final Map<DialogType, Widget Function(BuildContext, dynamic)> _dialogBuilders = {};
  final Map<BottomSheetType, Widget Function(BuildContext, dynamic)> _sheetBuilders = {};

  void registerDialogBuilder(DialogType type, Widget Function(BuildContext, dynamic) builder) {
    _dialogBuilders[type] = builder;
  }

  void registerSheetBuilder(BottomSheetType type, Widget Function(BuildContext, dynamic) builder) {
    _sheetBuilders[type] = builder;
  }

  Future<DialogResponse?> showCustomDialog({
    required DialogType variant,
    dynamic data,
    bool barrierDismissible = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    final builder = _dialogBuilders[variant];
    if (builder == null) {
      throw Exception('Dialog builder for variant $variant is not registered.');
    }

    return await showDialog<DialogResponse>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => builder(ctx, data),
    );
  }

  void completeDialog(DialogResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.canPop(context)) {
      Navigator.pop(context, response);
    }
  }

  Future<SheetResponse?> showCustomSheet({
    required BottomSheetType variant,
    dynamic data,
    bool isScrollControlled = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    final builder = _sheetBuilders[variant];
    if (builder == null) {
      throw Exception('Sheet builder for variant $variant is not registered.');
    }

    return await showModalBottomSheet<SheetResponse>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => builder(ctx, data),
    );
  }

  void completeSheet(SheetResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.canPop(context)) {
      Navigator.pop(context, response);
    }
  }
}
