import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Incremental migration boundary. Existing local repositories remain unchanged.
/// Remote money is a canonical integer string, parsed with BigInt when needed.
enum RepositoryMode { local, remote }

const repositoryMode =
    String.fromEnvironment('PLATFORM_REPOSITORY', defaultValue: 'local') ==
        'remote'
    ? RepositoryMode.remote
    : RepositoryMode.local;

abstract interface class AuthRepository {
  Future<Map<String, dynamic>> register(String email, String password);
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> currentUser();
  Future<void> refresh();
  Future<void> logout();
}

abstract interface class RiskRepository {
  Future<Map<String, dynamic>?> profile();
  Future<void> updateProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>> status();
  Future<Map<String, dynamic>> check(String proposedRiskMinor);
}

abstract interface class PlanRepository {
  Future<Map<String, dynamic>?> current();
  Future<Map<String, dynamic>> create(Map<String, dynamic> plan);
  Future<Map<String, dynamic>> update(Map<String, dynamic> plan);
}

abstract interface class TradingRepository {
  Future<Map<String, dynamic>> botStatus();
  Future<Map<String, dynamic>> startBot();
  Future<Map<String, dynamic>> pauseBot();
  Future<Map<String, dynamic>> resumeBot();
  Future<Map<String, dynamic>> stopBot();
  Future<Map<String, dynamic>> emergencyStop();
  Future<List<Map<String, dynamic>>> orders();
  Future<List<Map<String, dynamic>>> positions();
  Future<List<Map<String, dynamic>>> trades();
  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> order,
    String idempotencyKey,
  );
  Future<Map<String, dynamic>> cancelOrder(String orderId);
  Future<Map<String, dynamic>> closePosition(String positionId);
}

/// Transport implementation must add bearer credentials, rotate refresh tokens,
/// and store mobile refresh tokens in OS secure storage. No transport is wired
/// into the current local Flutter application in Phase 2.
abstract interface class AuthenticatedTransport {
  Future<Map<String, dynamic>?> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ]);
}

/// Production-shaped mobile transport: access tokens stay in memory and the
/// refresh token is held by OS secure storage. It retries one request after a
/// server-side refresh and never writes credentials to SharedPreferences.
class RemoteHttpTransport implements AuthenticatedTransport {
  RemoteHttpTransport(this.baseUrl, {http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(), _storage = storage ?? const FlutterSecureStorage();
  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  @override
  Future<Map<String, dynamic>?> request(String method, String path, [Map<String, dynamic>? body, Map<String, String>? headers]) async {
    final response = await _send(method, path, body, headers);
    if (response.statusCode == 401 && !path.contains('/auth/')) {
      final refreshToken = await _storage.read(key: 'tipkhun_refresh');
      if (refreshToken != null) {
        final refreshed = await _send('POST', '/api/v1/auth/refresh', {'refreshToken': refreshToken}, {'x-auth-client': 'mobile'});
        if (refreshed.statusCode < 300) { _accessToken = (jsonDecode(refreshed.body) as Map<String, dynamic>)['accessToken'] as String?; return _decode(await _send(method, path, body, headers)); }
      }
    }
    final decoded = await _decode(response);
    if (path.endsWith('/auth/login') && decoded?['refreshToken'] is String) {
      await _storage.write(key: 'tipkhun_refresh', value: decoded!['refreshToken'] as String);
    }
    return decoded;
  }
  Future<http.Response> _send(String method, String path, Map<String, dynamic>? body, Map<String, String>? headers) => _client.send(http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll({'content-type':'application/json', if (_accessToken != null) 'authorization':'Bearer $_accessToken', ...?headers})..body = body == null ? '' : jsonEncode(body)).then(http.Response.fromStream);
  Future<Map<String, dynamic>?> _decode(http.Response response) async { if (response.statusCode >= 400) { throw StateError('Remote API request failed: ${response.statusCode}'); } if (response.body.isEmpty) return null; final value=jsonDecode(response.body); return value is Map<String,dynamic> ? value : {'items':value}; }
}

abstract interface class AllocationRepository {
  Future<Map<String, dynamic>> settings();
  Future<void> updateSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>> available();
  Future<Map<String, dynamic>> preview([String? amountMinor]);
  Future<Map<String, dynamic>> confirm(String idempotencyKey);
  Future<List<Map<String, dynamic>>> history();
}
class RemoteAllocationRepository implements AllocationRepository {
  RemoteAllocationRepository(this.transport); final AuthenticatedTransport transport;
  @override Future<Map<String,dynamic>> settings() async => (await transport.request('GET','/api/v1/allocations/settings'))!;
  @override Future<void> updateSettings(Map<String,dynamic> s) async { await transport.request('PUT','/api/v1/allocations/settings',s); }
  @override Future<Map<String,dynamic>> available() async => (await transport.request('GET','/api/v1/allocations/available'))!;
  @override Future<Map<String,dynamic>> preview([String? amountMinor]) async => (await transport.request('POST','/api/v1/allocations/preview', amountMinor == null ? {} : {'amountMinor':amountMinor}))!;
  @override Future<Map<String,dynamic>> confirm(String key) async => (await transport.request('POST','/api/v1/allocations/confirm',{}, {'Idempotency-Key':key}))!;
  @override Future<List<Map<String,dynamic>>> history() async => ((await transport.request('GET','/api/v1/allocations/history'))?['items'] as List? ?? const []).cast<Map<String,dynamic>>();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this.transport);
  final AuthenticatedTransport transport;
  @override
  Future<Map<String, dynamic>> register(String email, String password) async =>
      (await transport.request('POST', '/api/v1/auth/register', {
        'email': email,
        'password': password,
      }))!;
  @override
  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await transport.request('POST', '/api/v1/auth/login', {
        'email': email,
        'password': password,
      }))!;
  @override
  Future<Map<String, dynamic>> currentUser() async =>
      (await transport.request('GET', '/api/v1/me'))!;
  @override
  Future<void> refresh() async {
    await transport.request('POST', '/api/v1/auth/refresh');
  }

  @override
  Future<void> logout() async {
    await transport.request('POST', '/api/v1/auth/logout');
    if (transport is RemoteHttpTransport) await (transport as RemoteHttpTransport)._storage.delete(key: 'tipkhun_refresh');
  }
}

class RemoteRiskRepository implements RiskRepository {
  RemoteRiskRepository(this.transport);
  final AuthenticatedTransport transport;
  @override
  Future<Map<String, dynamic>?> profile() =>
      transport.request('GET', '/api/v1/risk/profile');
  @override
  Future<void> updateProfile(Map<String, dynamic> profile) async {
    await transport.request('PUT', '/api/v1/risk/profile', profile);
  }

  @override
  Future<Map<String, dynamic>> status() async =>
      (await transport.request('GET', '/api/v1/risk/status'))!;
  @override
  Future<Map<String, dynamic>> check(String proposedRiskMinor) async =>
      (await transport.request('POST', '/api/v1/risk/check', {
        'proposedRiskMinor': proposedRiskMinor,
      }))!;
}

class RemotePlanRepository implements PlanRepository {
  RemotePlanRepository(this.transport);
  final AuthenticatedTransport transport;
  @override
  Future<Map<String, dynamic>?> current() =>
      transport.request('GET', '/api/v1/plans/current');
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> plan) async =>
      (await transport.request('POST', '/api/v1/plans', plan))!;
  @override
  Future<Map<String, dynamic>> update(Map<String, dynamic> plan) async =>
      (await transport.request('PUT', '/api/v1/plans/current', plan))!;
}

/// Remote paper endpoints. The existing local PaperEngine remains the default;
/// callers select this implementation only when PLATFORM_REPOSITORY=remote.
class RemoteTradingRepository implements TradingRepository {
  RemoteTradingRepository(this.transport);
  final AuthenticatedTransport transport;
  Future<Map<String, dynamic>> _bot(String action) async =>
      (await transport.request('POST', '/api/v1/bot/$action', const {}))!;
  @override
  Future<Map<String, dynamic>> botStatus() async =>
      (await transport.request('GET', '/api/v1/bot/status'))!;
  @override
  Future<Map<String, dynamic>> startBot() => _bot('start');
  @override
  Future<Map<String, dynamic>> pauseBot() => _bot('pause');
  @override
  Future<Map<String, dynamic>> resumeBot() => _bot('resume');
  @override
  Future<Map<String, dynamic>> stopBot() => _bot('stop');
  @override
  Future<Map<String, dynamic>> emergencyStop() => _bot('emergency-stop');
  @override
  Future<List<Map<String, dynamic>>> orders() async => _list('/api/v1/orders');
  @override
  Future<List<Map<String, dynamic>>> positions() async =>
      _list('/api/v1/positions');
  @override
  Future<List<Map<String, dynamic>>> trades() async => _list('/api/v1/trades');
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final value = await transport.request('GET', path);
    return ((value?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }
  @override
  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> order,
    String idempotencyKey,
  ) async => (await transport.request('POST', '/api/v1/orders', order, {
    'Idempotency-Key': idempotencyKey,
  }))!;
  @override
  Future<Map<String, dynamic>> cancelOrder(String orderId) async =>
      (await transport.request(
        'POST',
        '/api/v1/orders/$orderId/cancel',
        const {},
      ))!;
  @override
  Future<Map<String, dynamic>> closePosition(String positionId) async =>
      (await transport.request(
        'POST',
        '/api/v1/positions/$positionId/close',
        const {},
      ))!;
}
