import 'platform_repositories.dart';

/// Canonical money and quantity remain decimal strings supplied by the server.
abstract interface class PortfolioRepository {
  Future<Map<String, dynamic>> portfolio();
  Future<Map<String, dynamic>> cash();
  Future<List<Map<String, dynamic>>> holdings();
  Future<List<Map<String, dynamic>>> performance();
  Future<List<Map<String, dynamic>>> watchlist();
  Future<Map<String, dynamic>> fund(String amountMinor, String idempotencyKey);
  Future<Map<String, dynamic>> preview(
    String side,
    String symbol,
    String quantity,
  );
  Future<Map<String, dynamic>> order(
    String side,
    String symbol,
    String quantity,
    String idempotencyKey,
  );
  Future<List<Map<String, dynamic>>> fundingHistory();
  Future<List<Map<String, dynamic>>> orders();
  Future<List<Map<String, dynamic>>> targets();
  Future<void> updateTargets(List<Map<String, dynamic>> targets);
  Future<void> watch(String symbol);
  Future<void> unwatch(String symbol);
}

abstract interface class MarketDataRepository {
  Future<Map<String, dynamic>> quote(String symbol);
  Future<List<Map<String, dynamic>>> assets([String query]);
  Future<List<Map<String, dynamic>>> history(String symbol);
}

class RemotePortfolioRepository implements PortfolioRepository {
  RemotePortfolioRepository(this.transport);
  final AuthenticatedTransport transport;
  Future<Map<String, dynamic>> _get(String path) async =>
      (await transport.request('GET', '/api/v1$path'))!;
  Future<List<Map<String, dynamic>>> _list(String path) async =>
      ((await _get(path))['items'] as List).cast<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> portfolio() => _get('/portfolio');
  @override
  Future<Map<String, dynamic>> cash() => _get('/portfolio/cash');
  @override
  Future<List<Map<String, dynamic>>> holdings() => _list('/portfolio/holdings');
  @override
  Future<List<Map<String, dynamic>>> performance() =>
      _list('/portfolio/performance');
  @override
  Future<List<Map<String, dynamic>>> watchlist() => _list('/watchlist');
  @override
  Future<List<Map<String, dynamic>>> fundingHistory() =>
      _list('/portfolio/funding-history');
  @override
  Future<List<Map<String, dynamic>>> orders() => _list('/portfolio/orders');
  @override
  Future<List<Map<String, dynamic>>> targets() => _list('/portfolio/targets');
  @override
  Future<void> updateTargets(List<Map<String, dynamic>> targets) async {
    await transport.request('PUT', '/api/v1/portfolio/targets', {
      'targets': targets,
    });
  }

  @override
  Future<Map<String, dynamic>> fund(String amountMinor, String key) async =>
      (await transport.request(
        'POST',
        '/api/v1/portfolio/fund',
        {'amountMinor': amountMinor},
        {'Idempotency-Key': key},
      ))!;
  Map<String, dynamic> _order(String side, String symbol, String quantity) => {
    'side': side,
    'symbol': symbol,
    'quantity': quantity,
  };
  @override
  Future<Map<String, dynamic>> preview(
    String side,
    String symbol,
    String quantity,
  ) async => (await transport.request(
    'POST',
    '/api/v1/portfolio/orders/preview',
    _order(side, symbol, quantity),
  ))!;
  @override
  Future<Map<String, dynamic>> order(
    String side,
    String symbol,
    String quantity,
    String key,
  ) async => (await transport.request(
    'POST',
    '/api/v1/portfolio/orders',
    _order(side, symbol, quantity),
    {'Idempotency-Key': key},
  ))!;
  @override
  Future<void> watch(String symbol) async {
    await transport.request('POST', '/api/v1/watchlist', {'symbol': symbol});
  }

  @override
  Future<void> unwatch(String symbol) async {
    await transport.request(
      'DELETE',
      '/api/v1/watchlist/${Uri.encodeComponent(symbol)}',
    );
  }
}

class RemoteMarketDataRepository implements MarketDataRepository {
  RemoteMarketDataRepository(this.transport);
  final AuthenticatedTransport transport;
  @override
  Future<Map<String, dynamic>> quote(String symbol) async => (await transport
      .request('GET', '/api/v1/market/quotes/${Uri.encodeComponent(symbol)}'))!;
  @override
  Future<List<Map<String, dynamic>>> assets([String query = '']) async =>
      ((await transport.request(
                'GET',
                '/api/v1/market/assets?q=${Uri.encodeQueryComponent(query)}',
              ))!['items']
              as List)
          .cast<Map<String, dynamic>>();
  @override
  Future<List<Map<String, dynamic>>> history(String symbol) async =>
      ((await transport.request(
                'GET',
                '/api/v1/market/history/${Uri.encodeComponent(symbol)}',
              ))!['items']
              as List)
          .cast<Map<String, dynamic>>();
}

/// Feature flag selection. A null result leaves the existing local UI/repository
/// untouched; remote clients share the same authenticated transport instance.
PortfolioRepository? portfolioRepositoryForMode(
  AuthenticatedTransport transport, {
  RepositoryMode mode = repositoryMode,
}) =>
    mode == RepositoryMode.remote ? RemotePortfolioRepository(transport) : null;
MarketDataRepository? marketDataRepositoryForMode(
  AuthenticatedTransport transport, {
  RepositoryMode mode = repositoryMode,
}) => mode == RepositoryMode.remote
    ? RemoteMarketDataRepository(transport)
    : null;
