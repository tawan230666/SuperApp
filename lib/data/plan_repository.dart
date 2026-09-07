import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/investment_plan.dart';

abstract interface class PlanRepository {
  Future<InvestmentPlan?> load();
  Future<void> save(InvestmentPlan plan);
}

class LocalPlanRepository implements PlanRepository {
  static const key = 'tipkhun.plan.v1';
  @override
  Future<InvestmentPlan?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null
        ? null
        : InvestmentPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(InvestmentPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(plan.toJson()))) {
      throw StateError('Save failed');
    }
  }
}
