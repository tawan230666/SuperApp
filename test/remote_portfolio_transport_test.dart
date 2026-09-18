import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp/data/remote/platform_repositories.dart';
import 'package:superapp/data/remote/portfolio_repositories.dart';

void main() {
  test(
    'login authenticates requests; refresh rotates persisted session; logout clears it',
    () async {
      final store = MemoryRefreshTokenStore();
      var refreshes = 0;
      var calls = 0;
      final transport = RemoteHttpTransport(
        'http://localhost:3000',
        tokenStore: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({'accessToken': 'a1', 'refreshToken': 'r1'}),
              200,
            );
          }
          if (r.url.path.endsWith('/refresh')) {
            refreshes++;
            expect(
              jsonDecode(r.body)['refreshToken'],
              refreshes == 1 ? 'r1' : 'r2',
            );
            return http.Response(
              jsonEncode({
                'accessToken': 'a${refreshes + 1}',
                'refreshToken': 'r${refreshes + 1}',
              }),
              200,
            );
          }
          if (r.url.path.endsWith('/logout')) return http.Response('', 204);
          calls++;
          if (calls == 1) {
            expect(r.headers['authorization'], 'Bearer a1');
            return http.Response('{}', 401);
          }
          expect(r.headers['authorization'], 'Bearer a2');
          return http.Response('{"cashMinor":"123"}', 200);
        }),
      );
      final auth = RemoteAuthRepository(transport);
      await auth.login('a@example.test', 'password');
      expect(
        (await RemotePortfolioRepository(transport).cash())['cashMinor'],
        '123',
      );
      expect(await store.read(), 'r2');
      await auth.refresh();
      expect(await store.read(), 'r3');
      await auth.logout();
      expect(await store.read(), null);
      transport.close();
    },
  );
  test(
    'concurrent unauthorized reads rotate once and use server list contract',
    () async {
      final store = MemoryRefreshTokenStore();
      await store.write('r1');
      var rotations = 0;
      final transport = RemoteHttpTransport(
        'http://localhost:3000',
        tokenStore: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/refresh')) {
            rotations++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return http.Response(
              '{"accessToken":"a2","refreshToken":"r2"}',
              200,
            );
          }
          if (r.headers['authorization'] == null) {
            return http.Response('{}', 401);
          }
          return http.Response(
            '[{"id":"shared-holding","quantity":"0.123456"}]',
            200,
          );
        }),
      );
      final repository = RemotePortfolioRepository(transport);
      final result = await Future.wait([
        repository.holdings(),
        repository.holdings(),
      ]);
      expect(rotations, 1);
      expect(result[0][0]['quantity'], '0.123456');
      transport.close();
    },
  );
  test(
    'remote order sends exact quantity and idempotency without local financial overrides',
    () async {
      final transport = RemoteHttpTransport(
        'http://localhost:3000',
        tokenStore: MemoryRefreshTokenStore(),
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/portfolio/orders');
          expect(
            r.headers['Idempotency-Key'] ?? r.headers['idempotency-key'],
            'stable-key',
          );
          expect(jsonDecode(r.body), {
            'side': 'BUY',
            'symbol': 'PTT',
            'quantity': '2.123456',
          });
          return http.Response('{"id":"server-order"}', 201);
        }),
      );
      expect(
        (await RemotePortfolioRepository(
          transport,
        ).order('BUY', 'PTT', '2.123456', 'stable-key'))['id'],
        'server-order',
      );
      transport.close();
    },
  );
  test(
    'transport rejects insecure nonlocal server and clears invalid refresh session',
    () async {
      expect(
        () => RemoteHttpTransport('http://example.com'),
        throwsArgumentError,
      );
      final store = MemoryRefreshTokenStore();
      await store.write('expired');
      final transport = RemoteHttpTransport(
        'http://localhost:3000',
        tokenStore: store,
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      await expectLater(
        RemotePortfolioRepository(transport).cash(),
        throwsStateError,
      );
      expect(await store.read(), null);
      transport.close();
    },
  );
}
