import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/data/remote/platform_repositories.dart';
import 'package:superapp/data/remote/portfolio_repositories.dart';

void main() {
  test(
    'real Flutter transport reads React holding and allocation; SELL persists for React reload',
    () async {
      final path = Platform.environment['PORTFOLIO_SHARED_FIXTURE'];
      if (path == null) {
        throw StateError(
          'Run pnpm test:browser: shared backend fixture required',
        );
      }
      final fixture =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final transport = RemoteHttpTransport(
        'http://127.0.0.1:14000',
        tokenStore: MemoryRefreshTokenStore(),
      );
      try {
        final auth = RemoteAuthRepository(transport);
        await auth.login(
          fixture['email'] as String,
          fixture['password'] as String,
        );
        expect(repositoryMode, RepositoryMode.remote);
        final repository = portfolioRepositoryForMode(transport)!,
            market = marketDataRepositoryForMode(transport)!;
        var holdings = await repository.holdings();
        expect(holdings.single['id'], fixture['holdingId']);
        expect(holdings.single['quantity'], '10.000000');
        final allocations = await RemoteAllocationRepository(
          transport,
        ).history();
        expect(allocations.single['id'], fixture['allocationId']);
        await auth.refresh();
        await auth
            .refresh(); // verifies the rotated token is saved, not replayed
        expect((await market.quote('PTT'))['priceMinor'], '12');
        expect((await repository.portfolio())['unrealizedPnlMinor'], '19');
        final preview = await repository.preview('SELL', 'PTT', '4');
        expect(preview['amountMinor'], '48');
        final key = 'flutter-shared-${fixture['holdingId']}';
        final order = await repository.order('SELL', 'PTT', '4', key);
        expect(order['realized_pnl_minor'], '7');
        expect(
          (await repository.order('SELL', 'PTT', '4', key))['id'],
          order['id'],
        );
        holdings = await repository.holdings();
        expect(holdings.single['quantity'], '6.000000');
        await repository.watch('TDEX');
        expect((await repository.watchlist()).single['symbol'], 'TDEX');
        expect((await repository.performance()).isNotEmpty, true);
        await auth.logout();
        await expectLater(repository.cash(), throwsStateError);
      } finally {
        transport.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
