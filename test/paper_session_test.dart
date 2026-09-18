import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/data/paper_repository.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/state/paper_session.dart';

class DeferredPaperRepository implements PaperRepository {
  final result = Completer<String?>();
  @override
  Future<String?> load() => result.future;
  @override
  Future<void> save(String snapshot) async {}
}

void main() {
  test(
    'dispose during load does not publish or create an abandoned engine',
    () async {
      final repository = DeferredPaperRepository();
      final session = PaperSession(repository);
      var changes = 0;
      session.addListener(() => changes++);
      final loading = session.load(InvestmentPlan());
      expect(changes, 1);
      session.dispose();
      repository.result.complete(null);
      await loading;
      expect(changes, 1);
      expect(session.engine, isNull);
    },
  );

  test(
    'emergency completion does not clear busy while prior work is pending',
    () async {
      final session = PaperSession(DeferredPaperRepository());
      final pending = Completer<void>();
      var submissions = 0;
      final first = session.run(() => pending.future);
      await session.run(() async {}, emergency: true);
      expect(session.busy, isTrue);
      await session.run(() async {
        submissions++;
      });
      expect(submissions, 0);
      pending.complete();
      await first;
      expect(session.busy, isFalse);
      session.dispose();
    },
  );

  test(
    'in-flight work finishes after dispose but new actions are refused',
    () async {
      final session = PaperSession(DeferredPaperRepository());
      final pending = Completer<void>();
      var completed = false;
      var newAction = false;
      final running = session.run(() async {
        await pending.future;
        completed = true;
      });
      session.dispose();
      await session.run(() async {
        newAction = true;
      }, emergency: true);
      pending.complete();
      await running;
      expect(completed, isTrue);
      expect(newAction, isFalse);
    },
  );
}
