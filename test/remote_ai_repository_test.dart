import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/data/remote/ai_repository.dart';
import 'package:superapp/data/remote/platform_repositories.dart';

class TestTransport implements AuthenticatedTransport {
  final calls = <Map<String, Object?>>[];
  bool unavailable = false;
  final records = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>?> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  ]) async {
    calls.add({'method': method, 'path': path, 'body': body});
    if (unavailable) throw StateError('Remote API request failed: 503');
    if (method == 'GET') return {'items': records.toList()};
    return {'id': 'server-id', 'executionAuthorized': false, ...?body};
  }
}

void main() {
  test(
    'six advisory methods use canonical backend modes and only Copilot',
    () async {
      final transport = TestTransport();
      final ai = aiRepositoryForMode(transport, mode: RepositoryMode.remote)!;
      expect(
        aiRepositoryForMode(transport, mode: RepositoryMode.local),
        isNull,
      );
      await ai.portfolioReview();
      await ai.riskReview();
      await ai.tradingReview();
      await ai.profitReview();
      await ai.dailySummary();
      await ai.chat('ซื้อ PTT ให้ผม');
      expect(
        transport.calls.map((c) => (c['body'] as Map)['copilotMode']),
        CopilotMode.values.map((m) => m.apiValue),
      );
      expect(
        transport.calls.every((c) => c['path'] == '/api/v1/copilot/query'),
        true,
      );
    },
  );
  test(
    'history is fetched again and remote failure cannot return stale local history',
    () async {
      final transport = TestTransport(),
          ai = RemoteAIRepository(TestTransport());
      expect(await ai.history(), isEmpty);
      final repository = RemoteAIRepository(transport);
      transport.records.add({'id': 'postgres-id'});
      expect((await repository.history()).single['id'], 'postgres-id');
      transport.unavailable = true;
      await expectLater(repository.history(), throwsStateError);
      await expectLater(repository.chat('summary'), throwsStateError);
    },
  );
}
