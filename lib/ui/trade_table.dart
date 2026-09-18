import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/investment_plan.dart';

String csvCell(String value) {
  final safe = RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String tradeCsv(List<TradeRecord> records) => [
  [
    'Date',
    'Asset',
    'Strategy',
    'Side',
    'Entry',
    'Exit',
    'Gross P&L (satang)',
    'Fees (satang)',
    'Net P&L (satang)',
    'Risk',
    'Mode',
    'Status',
  ].map(csvCell).join(','),
  for (final t in records)
    [
      t.time.toUtc().toIso8601String(),
      t.asset,
      t.strategy,
      '',
      '',
      '',
      '${t.net + t.fees}',
      '${t.fees}',
      '${t.net}',
      t.outsidePlan ? 'Outside plan' : 'In plan',
      'Manual journal',
      'Recorded',
    ].map(csvCell).join(','),
].join('\r\n');

class JournalFilters extends StatelessWidget {
  const JournalFilters({
    super.key,
    required this.search,
    required this.asset,
    required this.strategy,
    required this.range,
    required this.trades,
    required this.onSearch,
    required this.onAsset,
    required this.onStrategy,
    required this.onRange,
  });
  final String search, asset, strategy;
  final DateTimeRange? range;
  final List<TradeRecord> trades;
  final ValueChanged<String> onSearch, onAsset, onStrategy;
  final ValueChanged<DateTimeRange?> onRange;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 220,
        child: _JournalSearch(
          value: search,
          onChanged: onSearch,
          decoration: const InputDecoration(
            labelText: 'ค้นหาเทรด',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          initialValue: asset,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'สินทรัพย์'),
          items: [
            const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
            for (final a in trades.map((t) => t.asset).toSet())
              DropdownMenuItem(
                value: a,
                child: Text(a, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => onAsset(v ?? ''),
        ),
      ),
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<String>(
          initialValue: strategy,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'กลยุทธ์'),
          items: [
            const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
            for (final a
                in trades
                    .map((t) => t.strategy)
                    .where((s) => s.isNotEmpty)
                    .toSet())
              DropdownMenuItem(
                value: a,
                child: Text(a, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => onStrategy(v ?? ''),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDateRangePicker(
            context: context,
            firstDate: DateTime(1970),
            lastDate: DateTime.now(),
            initialDateRange: range,
          );
          if (value != null) onRange(value);
        },
        icon: const Icon(Icons.date_range),
        label: Text(
          range == null
              ? 'เลือกช่วงวันที่'
              : '${dateLabel(range!.start).split(' ').first} – ${dateLabel(range!.end).split(' ').first}',
        ),
      ),
      if (range != null)
        TextButton(
          onPressed: () => onRange(null),
          child: const Text('ล้างวันที่'),
        ),
    ],
  );
}

class TradeTable extends StatefulWidget {
  const TradeTable({super.key, required this.records});
  final List<TradeRecord> records;
  @override
  State<TradeTable> createState() => _TradeTableState();
}

class _TradeTableState extends State<TradeTable> {
  late final source = _TradeSource(widget.records);
  @override
  void didUpdateWidget(TradeTable old) {
    super.didUpdateWidget(old);
    source.records = widget.records;
    source.refresh();
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Side / Entry / Exit ยังไม่มีในข้อมูลบันทึกเดิม แสดง — แทนการเดา\nRisk แสดงการทำตามแผน ไม่ใช่ risk amount • Manual journal ไม่ใช่ broker fill',
        style: TextStyle(fontSize: 12),
      ),
      TextButton.icon(
        icon: const Icon(Icons.download_outlined),
        label: const Text('Export CSV'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export CSV • ข้อมูลที่กรอง'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: SelectableText(tradeCsv(widget.records)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ปิด'),
              ),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: tradeCsv(widget.records)),
                  );
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('คัดลอก CSV แล้ว')),
                    );
                  }
                },
                child: const Text('คัดลอก CSV'),
              ),
            ],
          ),
        ),
      ),
      PaginatedDataTable(
        key: ValueKey(widget.records.length),
        rowsPerPage: 10,
        availableRowsPerPage: const [10],
        showFirstLastButtons: true,
        columns: [
          for (final label in [
            'Date',
            'Asset',
            'Strategy',
            'Side',
            'Entry',
            'Exit',
            'Gross P&L',
            'Fees',
            'Net P&L',
            'Risk',
            'Mode',
            'Status',
          ])
            DataColumn(label: Text(label)),
        ],
        source: source,
      ),
    ],
  );
}

class _TradeSource extends DataTableSource {
  _TradeSource(this.records);
  List<TradeRecord> records;
  void refresh() => notifyListeners();
  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final t = records[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        dateLabel(t.time),
        t.asset,
        t.strategy.isEmpty ? '—' : t.strategy,
        '—',
        '—',
        '—',
        money(t.net + t.fees),
        money(t.fees),
        money(t.net),
        t.outsidePlan ? 'นอกแผน' : 'ตามแผน',
        'Manual journal',
        'Recorded',
      ].map((s) => DataCell(Text(s))).toList(),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => records.length;
  @override
  int get selectedRowCount => 0;
}

class _JournalSearch extends StatefulWidget {
  const _JournalSearch({
    required this.value,
    required this.onChanged,
    required this.decoration,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  @override
  State<_JournalSearch> createState() => _JournalSearchState();
}

class _JournalSearchState extends State<_JournalSearch> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: widget.onChanged,
    decoration: widget.decoration,
  );
}
