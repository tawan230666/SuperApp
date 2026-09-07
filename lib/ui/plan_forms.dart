import 'package:flutter/material.dart';
import '../domain/investment_plan.dart';

Future<InvestmentPlan?> showPlanForm(
  BuildContext context,
  InvestmentPlan plan,
) => showDialog<InvestmentPlan>(
  context: context,
  builder: (_) => _PlanForm(plan),
);

class _PlanForm extends StatefulWidget {
  const _PlanForm(this.plan);
  final InvestmentPlan plan;
  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final key = GlobalKey<FormState>();
  late final List<TextEditingController> fields;
  late String level, cycle;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    level = p.riskLevel;
    cycle = p.cycle;
    fields = [
      p.capital / 100,
      p.dailyRate / 100,
      p.riskPerTrade / 100,
      p.maxTrades,
      p.dailyLossLimit / 100,
      p.target / 100,
    ].map((v) => TextEditingController(text: v.toString())).toList();
    fields[3].text = p.maxTrades.toString();
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  void preset(String value) {
    setState(() {
      level = value;
      if (value != 'Custom') {
        final rate = {'Low': 2, 'Medium': 5, 'High': 10}[value]!;
        final capital = parseMoney(fields[0].text);
        fields[1].text = '$rate';
        if (capital != null && capital > 0) {
          fields[2].text = (capital * rate / 100 / 3 / 100).toStringAsFixed(2);
          fields[4].text = (capital * rate / 100 / 100).toStringAsFixed(2);
        }
        fields[3].text = '3';
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ตั้งค่าแผนความเสี่ยง'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เริ่มจากค่าตั้งต้น แล้วปรับเงินและความเสี่ยงให้เหมาะกับแผนของคุณ',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: level,
                decoration: const InputDecoration(labelText: 'ระดับความเสี่ยง'),
                items: ['Low', 'Medium', 'High', 'Custom']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => preset(v!),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: fields[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: [
                        'เงินตั้งต้น (บาท)',
                        'งบความเสี่ยงต่อวัน (%)',
                        'ความเสี่ยงต่อเทรด (บาท)',
                        'จำนวนเทรดสูงสุดต่อวัน',
                        'ขีดจำกัดขาดทุนต่อวัน (บาท)',
                        'เป้าหมายกำไรต่อวัน (บาท)',
                      ][i],
                    ),
                    onChanged: (_) {
                      if (i == 1 || i == 2 || i == 3 || i == 4) {
                        setState(() => level = 'Custom');
                      }
                    },
                    validator: (v) {
                      if (i == 3) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > 10000
                            ? 'กรอกจำนวนเต็ม 1–10000'
                            : null;
                      }
                      final n = parseMoney(v ?? '');
                      if (n == null || n <= 0) {
                        return 'กรอกค่ามากกว่า 0 ทศนิยมไม่เกิน 2 ตำแหน่ง';
                      }
                      if (i == 1 && n > 10000) {
                        return 'เปอร์เซ็นต์ต้องไม่เกิน 100';
                      }
                      final capital = parseMoney(fields[0].text);
                      if ((i == 2 || i == 4) &&
                          capital != null &&
                          n > capital) {
                        return 'ความเสี่ยงต้องไม่เกินเงินตั้งต้น';
                      }
                      return null;
                    },
                  ),
                ),
              Text('ระดับที่ใช้: $level'),
              DropdownButtonFormField<String>(
                initialValue: cycle,
                decoration: const InputDecoration(labelText: 'รอบแบ่งกำไร'),
                items: ['Daily', 'Weekly', 'Monthly']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => cycle = v!,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          try {
            final p = InvestmentPlan(
              capital: parseMoney(fields[0].text)!,
              dailyRate: parseMoney(fields[1].text)!,
              riskPerTrade: parseMoney(fields[2].text)!,
              maximumTrades: int.parse(fields[3].text),
              dailyLossLimit: parseMoney(fields[4].text)!,
              target: parseMoney(fields[5].text)!,
              riskLevel: level,
              cycle: cycle,
            );
            p.setAllocation(
              widget.plan.shortPercent,
              widget.plan.longPercent,
              widget.plan.withdrawPercent,
            );
            Navigator.pop(context, p);
          } catch (_) {
            setState(() => error = 'กรุณาตรวจสอบแผน');
          }
        },
        child: const Text('ใช้แผนนี้'),
      ),
    ],
  );
}

class TradeInput {
  TradeInput(
    this.asset,
    this.gross,
    this.fees,
    this.time,
    this.note,
    this.strategy,
  );
  final String asset, note, strategy;
  final int gross, fees;
  final DateTime time;
}

Future<TradeInput?> showTradeForm(BuildContext context, InvestmentPlan plan) =>
    showDialog<TradeInput>(context: context, builder: (_) => _TradeForm(plan));

class _TradeForm extends StatefulWidget {
  const _TradeForm(this.plan);
  final InvestmentPlan plan;
  @override
  State<_TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<_TradeForm> {
  final key = GlobalKey<FormState>();
  final fields = List.generate(5, (_) => TextEditingController());
  DateTime time = DateTime.now();
  @override
  void initState() {
    super.initState();
    fields[2].text = '0';
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    final date = await showDatePicker(
      context: context,
      initialDate: time,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(time),
    );
    if (chosen == null || !mounted) return;
    setState(
      () => time = DateTime(
        date.year,
        date.month,
        date.day,
        chosen.hour,
        chosen.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('บันทึกผลเทรดที่ปิดแล้ว'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.plan.stopReason != null)
                Text(
                  widget.plan.stopReason!,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: fields[i],
                    keyboardType: i == 1 || i == 2
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: [
                        'ชื่อสินทรัพย์',
                        'กำไร / ขาดทุนก่อนค่าธรรมเนียม (บาท)',
                        'ค่าธรรมเนียม (บาท)',
                        'หมายเหตุ',
                        'Strategy (optional)',
                      ][i],
                    ),
                    validator: (v) {
                      if (i == 0 && (v ?? '').trim().isEmpty) {
                        return 'กรอกชื่อสินทรัพย์';
                      }
                      if (i == 1 || i == 2) {
                        final n = parseMoney(v ?? '');
                        if (n == null || i == 2 && n < 0) {
                          return 'กรอกจำนวนเงินให้ถูกต้อง';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              OutlinedButton.icon(
                onPressed: pick,
                icon: const Icon(Icons.event),
                label: Text(dateLabel(time)),
              ),
              if (time.isAfter(DateTime.now()))
                const Text(
                  'วันที่ต้องไม่อยู่ในอนาคต',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate() || time.isAfter(DateTime.now())) {
            return;
          }
          Navigator.pop(
            context,
            TradeInput(
              fields[0].text,
              parseMoney(fields[1].text)!,
              parseMoney(fields[2].text)!,
              time,
              fields[3].text,
              fields[4].text,
            ),
          );
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}

Future<List<int>?> showRatioForm(BuildContext context, InvestmentPlan plan) =>
    showDialog<List<int>>(context: context, builder: (_) => _RatioForm(plan));

class _RatioForm extends StatefulWidget {
  const _RatioForm(this.plan);
  final InvestmentPlan plan;
  @override
  State<_RatioForm> createState() => _RatioFormState();
}

class _RatioFormState extends State<_RatioForm> {
  late final List<TextEditingController> fields;
  String? error;
  @override
  void initState() {
    super.initState();
    fields = [
      widget.plan.shortPercent,
      widget.plan.longPercent,
      widget.plan.withdrawPercent,
    ].map((v) => TextEditingController(text: '$v')).toList();
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('สัดส่วนแบ่งกำไร'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: fields[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ['ระยะสั้น (%)', 'ระยะยาว (%)', 'ถอน (%)'][i],
                ),
              ),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          final v = fields.map((f) => int.tryParse(f.text) ?? -1).toList();
          if (v.any((n) => n < 0 || n > 100) ||
              v.reduce((a, b) => a + b) != 100) {
            setState(
              () => error = 'เปอร์เซ็นต์ต้องอยู่ในช่วง 0–100 และรวมกัน = 100%',
            );
            return;
          }
          Navigator.pop(context, v);
        },
        child: const Text('บันทึกสัดส่วน'),
      ),
    ],
  );
}
