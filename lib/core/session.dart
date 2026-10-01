import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'push.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();
  static const _key = 'court_hub_access_token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class Session extends ChangeNotifier {
  Session(this.api, this.store, [PushRegistrar? push])
      : push = push ?? NoopPushRegistrar() {
    api.onUnauthorized = expire;
  }
  final Api api;
  final TokenStore store;
  final PushRegistrar push;
  bool loading = true;
  String? restoreError;
  Map<String, dynamic>? user;
  List<String> roles = [];
  Map<String, dynamic>? facility;
  bool get signedIn => user != null;

  Future<void> restore() async {
    loading = true;
    restoreError = null;
    notifyListeners();
    try {
      final token = await store.read();
      if (token != null) {
        api.setToken(token);
        await hydrate();
        await _registerPush();
      }
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 401) {
        await store.clear();
      } else {
        restoreError = errorMessage(error);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> hydrate() async {
    final body = await api.request('/auth/me');
    final data = body['data'] as Map;
    user = Map<String, dynamic>.from(data['user'] as Map);
    facility = data['facility'] == null
        ? null
        : Map<String, dynamic>.from(data['facility'] as Map);
    roles = List<String>.from(data['roles'] as List);
    notifyListeners();
  }

  Future<void> login(String email, String password, String code) async {
    final body = await api.request('/auth/login', method: 'POST', data: {
      'email': email.trim(),
      'password': password,
      'device_name': 'Court Hub Mobile',
      if (code.trim().isNotEmpty) 'two_factor_code': code.trim(),
    });
    await establish(body);
  }

  Future<void> loginWithMockGoogle(String code) async {
    final body =
        await api.request('/auth/social/google', method: 'POST', data: {
      'mock_subject': 'demo-google-player-one',
      'email': 'demo.player1@court-hub.test',
      'name': 'Demo Player One',
      'device_name': 'Court Hub Mobile (mock social)',
      if (code.trim().isNotEmpty) 'two_factor_code': code.trim(),
    });
    await establish(body);
  }

  Future<void> registerPlayer(
      {required int facilityId,
      required String name,
      required String email,
      required String password,
      required String confirmation}) async {
    final body =
        await api.request('/auth/register-player', method: 'POST', data: {
      'facility_id': facilityId,
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': confirmation,
    });
    await establish(body);
  }

  Future<void> establish(dynamic body) async {
    final token = body['data']['token'] as String;
    api.setToken(token);
    try {
      await store.write(token);
      await hydrate();
      await _registerPush();
    } catch (_) {
      try {
        await api.request('/auth/logout', method: 'POST');
      } catch (_) {}
      api.setToken(null);
      user = null;
      roles = [];
      await store.clear();
      rethrow;
    }
  }

  void expire() {
    api.setToken(null);
    user = null;
    roles = [];
    facility = null;
    notifyListeners();
    // A rejected token is also removed on the next restoration attempt.
    store.clear().catchError((Object _) {});
  }

  Future<void> logout() async {
    // Keep the session on network failure so server revocation can be retried.
    try {
      await push.unregister(api);
    } catch (_) {}
    await api.request('/auth/logout', method: 'POST');
    await store.clear();
    expire();
  }

  Future<void> _registerPush() async {
    try {
      await push.register(api);
    } catch (_) {
      // Push setup cannot prevent a valid account session from being used.
    }
  }

  @override
  void dispose() {
    push.dispose();
    super.dispose();
  }
}
