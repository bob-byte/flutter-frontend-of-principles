import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/viewmodels/signup_viewmodel.dart';

void main() {
  late _FakeAuth auth;
  late SignupViewModel vm;

  setUp(() {
    auth = _FakeAuth();
    vm = SignupViewModel(auth);
  });

  Future<bool> register({bool succeed = true}) {
    auth.succeed = succeed;
    return vm.register(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'Secret123!',
      gender: 1,
      genericError: 'generic',
      emailAlreadyExistsError: 'exists',
    );
  }

  Future<int?> generateSignupCode() {
    return vm.generateSignupCode(
      'ada@example.com',
      genericError: 'generic',
      emailAlreadyExistsError: 'exists',
    );
  }

  test('successful register clears error', () async {
    expect(await register(), isTrue);
    expect(vm.error, isNull);
    expect(vm.isBusy, isFalse);
  });

  test('failed register sets generic error', () async {
    expect(await register(succeed: false), isFalse);
    expect(vm.error, 'generic');
  });

  test('maps duplicate-email exception', () async {
    auth.throwError = Exception('UserWithIdenticalEmailAlreadyExists');
    expect(await register(), isFalse);
    expect(vm.error, 'exists');
  });

  test('generateSignupCode returns code on success', () async {
    auth.signupCode = 123456;
    expect(await generateSignupCode(), 123456);
    expect(vm.error, isNull);
    expect(vm.isBusy, isFalse);
  });

  test('generateSignupCode maps duplicate-email exception', () async {
    auth.signupCodeError = Exception('UserWithIdenticalEmailAlreadyExists');
    expect(await generateSignupCode(), isNull);
    expect(vm.error, 'exists');
  });

  test('generateSignupCode sets generic error when code is null', () async {
    auth.signupCode = null;
    expect(await generateSignupCode(), isNull);
    expect(vm.error, 'generic');
  });
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(SecureStore());

  bool succeed = true;
  Object? throwError;
  int? signupCode = 111111;
  Object? signupCodeError;

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required int gender,
    String? mission,
    String? slogan,
  }) async {
    final err = throwError;
    if (err != null) throw err;
    return succeed;
  }

  @override
  Future<int?> generateSignupCode(String email, {String? language}) async {
    final err = signupCodeError;
    if (err != null) throw err;
    return signupCode;
  }
}
