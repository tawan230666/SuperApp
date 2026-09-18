import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/data/remote/platform_repositories.dart';
import 'package:superapp/data/remote/ai_repository.dart';

void main() {
  test(
    'Flutter reads identical React AI decision and appends shared advisory history',
    () async {
      final path = Platform.environment['AI_SHARED_FIXTURE'];
      if (path == null) {
        throw StateError('Run pnpm test:browser for real shared fixture');
      }
      final file = File(path);
      final fixture =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
        final ai = aiRepositoryForMode(transport)!;
        final decision = (await ai.history()).singleWhere(
          (d) => d['id'] == fixture['aiDecisionId'],
        );
        expect(decision['proposal'], fixture['aiProposal']);
        await auth.refresh();
        final context = await ai.context();
        expect((context['trading'] as Map)['netPnlMinor'], '1025');
        expect((context['profit'] as Map)['totalMinor'], '1025');
        for (final review in [
          ai.portfolioReview,
          ai.riskReview,
          ai.tradingReview,
          ai.profitReview,
          ai.dailySummary,
        ]) {
          final result = await review();
          expect(result['executionAuthorized'], false);
          expect(result['id'], isA<String>());
        }
        final refusal = await ai.chat('ซื้อ PTT ให้ผม');
        expect(refusal['intent'], 'REFUSED_EXECUTION');
        fixture['flutterAiDecisionId'] = refusal['id'];
        await file.writeAsString(jsonEncode(fixture));
        expect((await ai.history()).any((d) => d['id'] == refusal['id']), true);
        await auth.logout();
        await expectLater(ai.history(), throwsStateError);
      } finally {
        transport.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
