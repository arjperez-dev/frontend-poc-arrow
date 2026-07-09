import 'package:flutter/foundation.dart';

import '../application/login_use_case.dart';
import '../application/register_use_case.dart';
import '../domain/auth_session.dart';

enum AuthMode { login, register }

enum AuthScreenStatus { idle, submitting, success, failure }

class AuthScreenController extends ChangeNotifier {
  AuthScreenController({
    required LoginUseCase login,
    required RegisterUseCase register,
    Future<void> Function(String userId)? syncProgressOnLogin,
  }) : _login = login,
       _register = register,
       _syncProgressOnLogin = syncProgressOnLogin;

  final LoginUseCase _login;
  final RegisterUseCase _register;
  final Future<void> Function(String userId)? _syncProgressOnLogin;

  AuthMode _mode = AuthMode.login;
  AuthScreenStatus _status = AuthScreenStatus.idle;
  String? _errorMessage;
  AuthSession? _session;

  AuthMode get mode => _mode;
  AuthScreenStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;

  void toggleMode() {
    _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    _errorMessage = null;
    _status = AuthScreenStatus.idle;
    notifyListeners();
  }

  Future<void> submit({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _fail('Email and password are required.');
      return;
    }
    if (_mode == AuthMode.register && displayName.trim().isEmpty) {
      _fail('Display name is required.');
      return;
    }

    _status = AuthScreenStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = _mode == AuthMode.login
          ? await _login(email: email.trim(), password: password)
          : await _register(
              displayName: displayName.trim(),
              email: email.trim(),
              password: password,
            );
      final syncProgressOnLogin = _syncProgressOnLogin;
      if (syncProgressOnLogin != null) {
        try {
          await syncProgressOnLogin(_session!.user.id);
        } catch (_) {
          // Sync failure must not block login; local progress remains safe.
        }
      }

      _status = AuthScreenStatus.success;
      notifyListeners();
    } catch (error) {
      _fail(error.toString());
    }
  }

  void _fail(String message) {
    _errorMessage = message;
    _status = AuthScreenStatus.failure;
    notifyListeners();
  }
}
