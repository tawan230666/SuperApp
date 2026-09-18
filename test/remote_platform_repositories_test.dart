import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/data/remote/platform_repositories.dart';

class FakeTransport implements AuthenticatedTransport {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>?> request(String method, String path,
      [Map<String, dynamic>? body, Map<String, String>? headers]) async {
    calls.add('$method $path ${headers?['Idempotency-Key'] ?? ''}');
    if (path.endsWith('/allocations/history')) return {'items': [{'id': 'batch-1'}]};
    if (path.endsWith('/allocations/settings')) return {'shortTermBps': 5000, 'longTermBps': 3000, 'withdrawalBps': 2000};
    return {'ok': true};
  }
}

void main() {
  test('remote allocation repository uses shared authenticated contract', () async {
    final transport = FakeTransport();
    final repository = RemoteAllocationRepository(transport);
    expect((await repository.history()).single['id'], 'batch-1');
    await repository.confirm('allocation-test-1');
    expect(transport.calls, contains('POST /api/v1/allocations/confirm allocation-test-1'));
  });
}
