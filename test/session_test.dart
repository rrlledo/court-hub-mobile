import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/core/push.dart';
import 'package:court_hub_mobile/core/session.dart';

class MemoryTokens implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FakeApi extends Api {
  Object? failure;
  final calls = <String>[];
  Map<String, dynamic>? loginData;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    calls.add(path);
    if (failure != null) throw failure!;
    if (path == '/auth/login') {
      loginData = data;
      return {
        'data': {'token': 'test-token'}
      };
    }
    if (path == '/auth/me') {
      return {
        'data': {
          'user': {'id': 7, 'name': 'Player'},
          'roles': ['player']
        }
      };
    }
    return null;
  }
}

class FakePushRegistrar implements PushRegistrar {
  var registrations = 0;
  var unregistrations = 0;
  @override
  void dispose() {}
  @override
  Future<void> register(Api api) async => registrations++;
  @override
  Future<void> unregister(Api api) async => unregistrations++;
  @override
  void setInteractionHandler(
      void Function(PushInteraction interaction)? handler) {}
}

void main() {
  test('login fetches roles from me and persists token', () async {
    final api = FakeApi();
    final store = MemoryTokens();
    final session = Session(api, store);
    await session.login(' player@example.com ', 'password', '123456');
    expect(session.roles, ['player']);
    expect(session.signedIn, isTrue);
    expect(store.token, 'test-token');
    expect(api.loginData?['two_factor_code'], '123456');
    expect(api.loginData?['email'], 'player@example.com');
    session.dispose();
  });
  test('login registers the device and logout removes it', () async {
    final api = FakeApi();
    final push = FakePushRegistrar();
    final session = Session(api, MemoryTokens(), push);
    await session.login('p@example.com', 'password', '');
    await session.logout();
    expect(push.registrations, 1);
    expect(push.unregistrations, 1);
    session.dispose();
  });
  test('offline restore preserves token and supports retry', () async {
    final api = FakeApi()
      ..failure = DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          type: DioExceptionType.connectionError);
    final store = MemoryTokens()..token = 'saved-token';
    final session = Session(api, store);
    await session.restore();
    expect(store.token, 'saved-token');
    expect(session.restoreError, isNotNull);
    api.failure = null;
    await session.restore();
    expect(session.signedIn, isTrue);
    expect(session.restoreError, isNull);
    session.dispose();
  });
  test('logout revokes server token and clears local identity', () async {
    final api = FakeApi();
    final store = MemoryTokens();
    final session = Session(api, store);
    await session.login('p@example.com', 'password', '');
    await session.logout();
    expect(api.calls.last, '/auth/logout');
    expect(store.token, isNull);
    expect(session.signedIn, isFalse);
    expect(api.dio.options.headers.containsKey('Authorization'), isFalse);
    session.dispose();
  });
}
