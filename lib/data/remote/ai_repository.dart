import 'platform_repositories.dart';

/// Advisory requests only. Financial execution is deliberately not an API here.
enum CopilotMode {
  portfolioReview('PORTFOLIO_REVIEW'),
  riskReview('RISK_REVIEW'),
  tradingReview('TRADING_REVIEW'),
  profitReview('PROFIT_REVIEW'),
  dailySummary('DAILY_SUMMARY'),
  askFinancialQuestion('ASK_FINANCIAL_QUESTION');

  const CopilotMode(this.apiValue);
  final String apiValue;
}

abstract interface class AIRepository {
  Future<Map<String, dynamic>> context();
  Future<Map<String, dynamic>> chat(String question);
  Future<Map<String, dynamic>> portfolioReview();
  Future<Map<String, dynamic>> riskReview();
  Future<Map<String, dynamic>> tradingReview();
  Future<Map<String, dynamic>> profitReview();
  Future<Map<String, dynamic>> dailySummary();
  Future<List<Map<String, dynamic>>> history();
}

/// PostgreSQL history through the same Gateway used by React; no local fallback.
class RemoteAIRepository implements AIRepository {
  RemoteAIRepository(this.transport);
  final AuthenticatedTransport transport;

  Future<Map<String, dynamic>> _query(String question, CopilotMode mode) async {
    final result = await transport.request('POST', '/api/v1/copilot/query', {
      'question': question,
      'copilotMode': mode.apiValue,
    });
    if (result == null || result['executionAuthorized'] != false) {
      throw StateError('Invalid advisory response');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> context() async =>
      (await transport.request('GET', '/api/v1/copilot/context'))!;
  @override
  Future<Map<String, dynamic>> chat(String question) =>
      _query(question, CopilotMode.askFinancialQuestion);
  @override
  Future<Map<String, dynamic>> portfolioReview() =>
      _query('ทบทวนพอร์ตการลงทุน', CopilotMode.portfolioReview);
  @override
  Future<Map<String, dynamic>> riskReview() =>
      _query('ทบทวนข้อจำกัดความเสี่ยง', CopilotMode.riskReview);
  @override
  Future<Map<String, dynamic>> tradingReview() =>
      _query('ทบทวนประวัติเทรด', CopilotMode.tradingReview);
  @override
  Future<Map<String, dynamic>> profitReview() =>
      _query('ทบทวนกำไรที่จัดสรรแล้ว', CopilotMode.profitReview);
  @override
  Future<Map<String, dynamic>> dailySummary() =>
      _query('สรุปสถานะการลงทุนของฉัน', CopilotMode.dailySummary);
  @override
  Future<List<Map<String, dynamic>>> history() async {
    final response = await transport.request('GET', '/api/v1/copilot/decisions');
    if (response == null || response['items'] is! List) {
      throw StateError('Invalid advisory history response');
    }
    return (response['items'] as List).cast<Map<String, dynamic>>();
  }
}

AIRepository? aiRepositoryForMode(
  AuthenticatedTransport transport, {
  RepositoryMode mode = repositoryMode,
}) => mode == RepositoryMode.remote ? RemoteAIRepository(transport) : null;
