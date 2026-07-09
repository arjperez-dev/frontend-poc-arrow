abstract interface class ApiClient {
  Future<Object?> get(String path, {bool authenticated = false});

  Future<Object?> post(String path, {Object? body, bool authenticated = false});

  Future<Object?> put(String path, {Object? body, bool authenticated = false});

  Future<Object?> delete(String path, {bool authenticated = false});
}
