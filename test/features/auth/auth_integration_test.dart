import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/network/api_client.dart';
import 'package:frontend_poc_arrow/features/auth/application/login_use_case.dart';
import 'package:frontend_poc_arrow/features/auth/application/token_storage.dart';
import 'package:frontend_poc_arrow/features/auth/domain/auth_session.dart';
import 'package:frontend_poc_arrow/features/auth/infrastructure/api_auth_repository.dart';

void main() {
  test('should_login_user_when_credentials_are_valid', () async {
    final repository = ApiAuthRepository(_FakeApiClient());

    final session = await repository.login(
      email: 'player@example.com',
      password: 'StrongPass123',
    );

    expect(session.accessToken, 'jwt-token');
    expect(session.user.email, 'player@example.com');
  });

  test('should_store_token_when_login_succeeds', () async {
    final tokenStorage = _InMemoryTokenStorage();
    final login = LoginUseCase(
      ApiAuthRepository(_FakeApiClient()),
      tokenStorage,
    );

    await login(email: 'player@example.com', password: 'StrongPass123');

    expect(await tokenStorage.getAccessToken(), 'jwt-token');
  });
}

class _FakeApiClient implements ApiClient {
  @override
  Future<Object?> get(String path, {bool authenticated = false}) async => null;

  @override
  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    return {
      'accessToken': 'jwt-token',
      'user': {
        'id': 'user-1',
        'email': 'player@example.com',
        'displayName': 'Player',
        'role': 'PLAYER',
      },
    };
  }

  @override
  Future<Object?> put(
    String path, {
    Object? body,
    bool authenticated = false,
  }) async => null;

  @override
  Future<Object?> delete(String path, {bool authenticated = false}) async =>
      null;
}

class _InMemoryTokenStorage implements TokenStorage {
  AuthSession? session;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String?> getAccessToken() async => session?.accessToken;

  @override
  Future<AuthSession?> getSession() async => session;

  @override
  Future<void> saveSession(AuthSession session) async {
    this.session = session;
  }
}
