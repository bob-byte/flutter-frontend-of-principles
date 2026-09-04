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
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(SecureStore());

  bool succeed = true;
  Object? throwError;

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
}
