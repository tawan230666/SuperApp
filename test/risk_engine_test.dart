import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/domain/investment_plan.dart';

void main() {
  test('losses consume budget and wins never restore it', () {
    final plan = InvestmentPlan();
    expect(plan.budget, 1750);
    expect(plan.maxTrades, 3);
    plan.record('A', -500);
    plan.record('A', -500);
    expect(plan.remaining, 750);
    expect(plan.tradesLeft, 1);
    plan.record('A', 1000);
    expect(plan.remaining, 750);
    expect(plan.stopReason, isNotNull);
  });
  test('stop latches and actual losses beyond plan can be recorded', () {
    final plan = InvestmentPlan();
    plan.record('A', 3000);
    plan.record('A', -5000);
    expect(plan.trades.last.outsidePlan, isTrue);
    expect(plan.remaining, 0);
    expect(plan.stopReason, isNotNull);
  });
  test('allocation preserves satang and cannot reuse prior profit', () {
    final plan = InvestmentPlan();
    plan.record('A', 10001);
    plan.allocate();
    expect(plan.reinvestment + plan.longTerm + plan.withdrawal, 10001);
    plan.allocate();
    expect(plan.allocated, 10001);
    plan.record('A', -2000);
    expect(plan.distributable, 0);
    plan.record('A', 2500);
    expect(plan.distributable, 500);
  });
  test('invalid plans and money inputs are rejected', () {
    expect(() => InvestmentPlan(riskPerTrade: 0), throwsArgumentError);
    expect(parseMoney('1.001'), isNull);
    expect(parseMoney('NaN'), isNull);
    expect(parseMoney('-5.01'), -501);
    expect(InvestmentPlan(riskPerTrade: 2000).tradesLeft, 0);
  });
}
