import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/app_benefits_viewmodel.dart';

void main() {
  group('AppBenefitsViewModel navigateToNextViewAction', () {
    test('returns goBack when user is logged in', () async {
      final vm = AppBenefitsViewModel(
        AuthService(SecureStore()),
        tokenReader: () async => 'token',
      );

      final action = await vm.navigateToNextViewAction();
      expect(action, AppBenefitsNavigationAction.goBack);
    });

    test('returns startupAbsolute when user is not logged in', () async {
      final vm = AppBenefitsViewModel(
        AuthService(SecureStore()),
        tokenReader: () async => null,
      );

      final action = await vm.navigateToNextViewAction();
      expect(action, AppBenefitsNavigationAction.startupAbsolute);
    });
  });
}
