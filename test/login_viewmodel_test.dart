import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/login_viewmodel.dart';

void main() {
  late _FakeAuth auth;
  late LoginViewModel vm;

  setUp(() {
    auth = _FakeAuth();
    vm = LoginViewModel(auth);
  });

  tearDown(() => vm.dispose());

  Future<bool> attempt({bool succeed = false}) {
    auth.succeed = succeed;
    return vm.login(
      'ada@example.com',
      'secret',
      genericError: 'generic',
      invalidCredentialsError: 'invalid',
      formatTimerMessage: (s) => 'wait $s',
    );
  }

  test('successful login clears failed attempts', () async {
    auth.succeed = false;
    await attempt();
    await attempt();
    expect(await attempt(succeed: true), isTrue);
    expect(vm.error, isNull);
    expect(vm.isTimerVisible, isFalse);
    expect(vm.isLoginEnable, isTrue);
  });

  test('failed login sets generic error and increments toward lockout', () async {
    expect(await attempt(), isFalse);
    expect(vm.error, 'generic');
    expect(vm.isTimerVisible, isFalse);
  });

  test('locks out after five failed attempts', () async {
    for (var i = 0; i < 5; i++) {
      await attempt();
    }
    expect(vm.isTimerVisible, isTrue);
    expect(vm.isLoginEnable, isFalse);
    expect(vm.timerMessage, 'wait 30');
    expect(await attempt(), isFalse);
  });

  test('maps InvalidEmailOrPassword exception to invalid credentials', () async {
    auth.throwError = Exception('InvalidEmailOrPassword');
    expect(await attempt(), isFalse);
    expect(vm.error, 'invalid');
  });
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(SecureStore());

  bool succeed = false;
  Object? throwError;

  @override
  Future<bool> login(String email, String password) async {
    final err = throwError;
    if (err != null) throw err;
    return succeed;
  }
}
