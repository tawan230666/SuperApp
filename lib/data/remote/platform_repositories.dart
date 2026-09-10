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

/// Transport implementation must add bearer credentials, rotate refresh tokens,
/// and store mobile refresh tokens in OS secure storage. No transport is wired
/// into the current local Flutter application in Phase 2.
abstract interface class AuthenticatedTransport {
  Future<Map<String, dynamic>?> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]);
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
