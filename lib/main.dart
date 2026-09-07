import 'dart:async';
import 'package:flutter/material.dart';
import 'data/plan_repository.dart';
import 'domain/investment_plan.dart';
import 'services/assistant_service.dart';
import 'state/plan_store.dart';
import 'ui/plan_forms.dart';
import 'ui/brand_mark.dart';
import 'ui/workspace_widgets.dart';
import 'ui/dashboard.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.repository, this.assistantService});
  final PlanRepository? repository;
  final AssistantService? assistantService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tipkhun Capital',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansThai',
      colorScheme: const ColorScheme.light(
        primary: green,
        onPrimary: Colors.white,
        secondary: green,
        onSecondary: Colors.white,
        secondaryContainer: mint,
        onSecondaryContainer: ink,
        surface: surface,
        onSurface: ink,
        surfaceContainerHighest: mint,
        outline: border,
        error: Color(0xFFAD5142),
      ),
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 28,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: mint,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: green)),
        elevation: 0,
        height: 74,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: charcoal,
        indicatorColor: Color(0xFF425142),
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: railText),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          color: railText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: canvas,
        selectedColor: mint,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          color: ink,
          fontSize: 12,
        ),
        padding: const EdgeInsets.all(7),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(fontFamily: 'NotoSansThai', color: muted),
        contentPadding: const EdgeInsets.all(18),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
        headlineMedium: TextStyle(
          fontSize: 27,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    ),
    home: CapitalHome(
      repository: repository ?? LocalPlanRepository(),
      assistantService: assistantService ?? LocalAssistantService(),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.full = false});
  final bool full;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BrandMark(size: 42),
      if (full) ...[
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Tipkhun Capital',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ],
  );
}

class CapitalHome extends StatefulWidget {
  const CapitalHome({
    super.key,
    required this.repository,
    required this.assistantService,
  });
  final PlanRepository repository;
  final AssistantService assistantService;
  @override
  State<CapitalHome> createState() => _CapitalHomeState();
}

class _CapitalHomeState extends State<CapitalHome> with WidgetsBindingObserver {
  late final PlanStore store;
  InvestmentPlan get plan => store.plan;
  int page = 0, filter = 0;
  bool chatting = false;
  String? chatError;
  final messages = <({bool user, String text})>[];
  final chat = TextEditingController();
  Timer? timer;
  static const labels = [
    'ภาพรวม',
    'บันทึกเทรด',
    'แบ่งกำไร',
    'ระยะยาว',
    'ผู้ช่วย',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.call_split,
    Icons.savings_outlined,
    Icons.chat_bubble_outline,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = PlanStore(widget.repository)..addListener(refresh);
    store.load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(refresh);
    store.dispose();
    chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final now = DateTime.now();
    final date =
        '${now.day} ${const ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'][now.month - 1]} ${now.year + 543}';
    final titles = [
      'วันนี้ของคุณ',
      'สมุดบันทึกเทรด',
      'จัดสรรให้ทุกเป้าหมาย',
      'สร้างอนาคตทีละก้าว',
      'มาคุยเรื่องแผนของคุณ',
    ];
    final descriptions = [
      'จัดการความเสี่ยง แล้วก้าวต่ออย่างมีแผน',
      'เก็บผลลัพธ์ เรียนรู้จากทุกการตัดสินใจ',
      'เปลี่ยนกำไร ให้เป็นส่วนหนึ่งของแผนระยะยาว',
      'ติดตามเงินที่คุณกันไว้สำหรับระยะยาว',
      'ทบทวนตัวเลขและสถานะจากบันทึกของคุณ',
    ];
    final content = store.loading
        ? const Center(child: CircularProgressIndicator())
        : store.error != null && store.error!.startsWith('อ่าน')
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.error!),
                FilledButton(
                  onPressed: store.load,
                  child: const Text('ลองใหม่'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              if (store.saving) const LinearProgressIndicator(minHeight: 2),
              if (store.error != null)
                MaterialBanner(
                  content: Text(store.error!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => store.error = null),
                      child: const Text('ปิด'),
                    ),
                  ],
                ),
              Expanded(
                child: ListView(
                  key: ValueKey(page),
                  padding: EdgeInsets.fromLTRB(
                    wide ? 40 : 20,
                    wide ? 36 : 12,
                    wide ? 40 : 20,
                    30,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: page == 4
                              ? 780
                              : page == 1 || page == 3
                              ? 960
                              : 1160,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        page == 0
                                            ? date
                                            : 'TIPKHUN / ${labels[page]}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                          letterSpacing: .5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        titles[page],
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        descriptions[page],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (wide) ...[
                                  const SizedBox(width: 16),
                                  const StatusPill('รุ่นทดลอง · Beta'),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: settings,
                                    tooltip: 'ตั้งค่า',
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 26),
                            ...switch (page) {
                              0 => [
                                Dashboard(
                                  plan: plan,
                                  saving: store.saving,
                                  onConfigure: configure,
                                  onRecord: recordTrade,
                                  onNavigate: (i) => setState(() => page = i),
                                ),
                              ],
                              1 => journal(),
                              2 => router(),
                              3 => longTerm(),
                              _ => assistant(),
                            },
                            const SizedBox(height: 24),
                            const Text(
                              'ข้อมูลอยู่บนอุปกรณ์นี้  ·  เครื่องมือวางแผน ไม่รับประกันผลตอบแทน',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              titleSpacing: 20,
              title: const Brand(full: true),
              actions: [
                IconButton(
                  onPressed: settings,
                  tooltip: 'ตั้งค่า',
                  icon: const Icon(Icons.tune_rounded, size: 22),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        top: wide,
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 228,
                child: ColoredBox(
                  color: charcoal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 30, 16, 34),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontFamily: 'NotoSansThai',
                            color: Colors.white,
                          ),
                          child: Brand(full: true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 28, bottom: 14),
                        child: Text(
                          'พื้นที่ของคุณ',
                          style: TextStyle(fontSize: 11, color: railText),
                        ),
                      ),
                      Expanded(
                        child: NavigationRail(
                          extended: true,
                          minExtendedWidth: 228,
                          selectedIndex: page,
                          onDestinationSelected: (i) =>
                              setState(() => page = i),
                          destinations: List.generate(
                            5,
                            (i) => NavigationRailDestination(
                              icon: Icon(icons[i], size: 21),
                              label: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF303D35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.phone_android_outlined,
                              color: lime,
                              size: 20,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'แผนของคุณ บนอุปกรณ์นี้',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ยังไม่มีการซิงค์ข้ามอุปกรณ์',
                              style: TextStyle(fontSize: 10, color: railText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: border)),
              ),
              child: NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (i) => setState(() => page = i),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 10,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? green
                        : muted,
                  ),
                ),
                destinations: List.generate(
                  5,
                  (i) => NavigationDestination(
                    icon: Icon(icons[i], size: 22),
                    label: labels[i],
                  ),
                ),
              ),
            ),
    );
  }

  Widget panel({required Widget child, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: WorkspaceCard(color: color ?? surface, child: child),
  );
  Widget heading(String t) => SectionTitle(t);
  Widget line(String t, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 270
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(color: muted, fontSize: 13)),
                Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    v,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    ),
  );
  List<TradeRecord> get filtered => plan.trades
      .where((t) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        return filter == 3 ||
            filter == 0 && sameDay(t.time, now) ||
            filter > 0 &&
                !t.time.isBefore(
                  start.subtract(Duration(days: filter == 1 ? 6 : 29)),
                );
      })
      .toList()
      .reversed
      .toList();
  List<Widget> journal() {
    final records = filtered;
    final net = records.fold(0, (sum, t) => sum + t.net);
    return [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: store.saving ? null : recordTrade,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('บันทึกผลเทรด'),
        ),
      ),
      const SizedBox(height: 18),
      panel(
        color: const Color(0xFFE4E9DE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ผลสุทธิในช่วงที่เลือก',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 6),
            Amount(money(net), size: 36, color: net < 0 ? negative : green),
            const SizedBox(height: 8),
            Text(
              '${records.length} รายการ · หักค่าธรรมเนียมแล้ว',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              'รายการเทรด',
              subtitle: 'เลือกช่วงเวลาเพื่อทบทวนบันทึก',
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                4,
                (i) => ChoiceChip(
                  label: Text(['วันนี้', '7 วัน', '30 วัน', 'ทั้งหมด'][i]),
                  selected: filter == i,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = i),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (records.isEmpty) const EmptyJournal(),
            ...records.map(
              (t) => Column(
                children: [
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        t.net < 0 ? Icons.south_east : Icons.north_east,
                        color: t.net < 0 ? negative : green,
                        background: t.net < 0 ? const Color(0xFFF3E5E0) : mint,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.asset,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              dateLabel(t.time),
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                            if (t.outsidePlan)
                              const Text(
                                'นอกแผนความเสี่ยง',
                                style: TextStyle(color: negative, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Amount(
                          money(t.net),
                          size: 20,
                          color: t.net < 0 ? negative : green,
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'รายละเอียดรายการ',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    children: [
                      line('ค่าธรรมเนียม', money(t.fees)),
                      if (t.strategy.isNotEmpty) line('กลยุทธ์', t.strategy),
                      if (t.note.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(t.note),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _bucket(
    String title,
    String subtitle,
    int percent,
    int amount,
    IconData icon,
    Color color,
  ) => WorkspaceCard(
    color: color,
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: green, size: 22),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 14),
        Amount(money(amount), size: 26),
      ],
    ),
  );

  Widget _responsiveCards(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 650) {
        return Column(
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ),
              )
              .toList(),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: cards[i]),
          ],
        ],
      );
    },
  );

  List<Widget> router() {
    final a = plan.preview();
    return [
      panel(
        color: charcoal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ให้กำไรเดินทางต่อ',
              style: TextStyle(fontSize: 13, color: railText),
            ),
            const SizedBox(height: 16),
            Amount(money(a.amount), size: 44, color: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'กำไรสุทธิที่พร้อมจัดสรร',
              style: TextStyle(fontSize: 12, color: railText),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.event_repeat_rounded, size: 17, color: lime),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'แผนแบ่ง${{'Daily': 'รายวัน', 'Weekly': 'รายสัปดาห์', 'Monthly': 'รายเดือน'}[plan.cycle]} · ยืนยันด้วยตนเอง',
                    style: const TextStyle(color: railText, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SectionTitle(
        'แบ่งกำไร 3 ส่วน',
        subtitle: 'กำหนดปลายทางของเงินก่อนยืนยัน',
        action: TextButton(
          onPressed: store.saving ? null : ratios,
          child: const Text('แก้สัดส่วน'),
        ),
      ),
      _responsiveCards([
        _bucket(
          'ต่อยอดทุน',
          'สำหรับแผนระยะสั้น',
          plan.shortPercent,
          a.short,
          Icons.autorenew_rounded,
          const Color(0xFFE1E9DD),
        ),
        _bucket(
          'สะสมระยะยาว',
          'สำหรับเป้าหมายในอนาคต',
          plan.longPercent,
          a.long,
          Icons.savings_outlined,
          const Color(0xFFE4E8E9),
        ),
        _bucket(
          'กันไว้ถอน',
          'สำหรับนำออกมาใช้',
          plan.withdrawPercent,
          a.withdraw,
          Icons.account_balance_wallet_outlined,
          const Color(0xFFEDE7DB),
        ),
      ]),
      const SizedBox(height: 20),
      panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('ตรวจสอบก่อนจัดสรร'),
            if (a.amount == 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'เมื่อมีกำไรสุทธิเหลือจากยอดที่เคยจัดสรร คุณจะแบ่งกำไรได้ที่นี่',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: store.saving || a.amount == 0 ? null : allocate,
                icon: const Icon(Icons.check_rounded, size: 19),
                label: const Text('ตรวจสอบและแบ่งกำไร'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'เป็นการบันทึกแผน ไม่มีการโอนเงินจริง',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const Divider(),
            const SectionTitle('ยอดจัดสรรสะสม'),
            line('ทุนระยะสั้น', money(plan.reinvestment)),
            line('เงินระยะยาว', money(plan.longTerm)),
            line('เงินสำหรับถอน', money(plan.withdrawal)),
            if (plan.allocated > plan.totalPnl)
              const Text(
                'กำไรลดลงหลังจัดสรร พักการแบ่งเพิ่มจนกว่ากำไรสุทธิจะเกินยอดที่เคยแบ่ง',
                style: TextStyle(color: negative, fontSize: 12),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> longTerm() => [
    panel(
      color: const Color(0xFFE4E9DE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            Icons.savings_outlined,
            background: surface,
            size: 48,
          ),
          const SizedBox(height: 22),
          const Text(
            'เงินที่กันไว้ระยะยาว',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 6),
          Amount(money(plan.longTerm), size: 44),
          const SizedBox(height: 10),
          const Text(
            'ทีละส่วนของกำไร เพื่อเป้าหมายที่ใหญ่ขึ้น',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => setState(() => page = 2),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('จัดสรรเพิ่ม'),
          ),
        ],
      ),
    ),
    panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'เส้นทางการสะสม',
            subtitle: 'ประวัติเงินที่คุณแบ่งเข้าระยะยาว',
          ),
          if (plan.allocations.isEmpty)
            const EmptyJournal(
              title: 'เป้าหมายระยะยาว เริ่มได้จากก้าวเล็ก ๆ',
              description:
                  'เมื่อแบ่งกำไรเข้าระยะยาว\nยอดสะสมแต่ละครั้งจะแสดงที่นี่',
            ),
          ...plan.allocations.reversed.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const IconBadge(Icons.south_west_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel(a.time),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'จากกำไร ${money(a.amount)}',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Flexible(child: Amount(money(a.long), size: 20)),
                ],
              ),
            ),
          ),
          const Divider(),
          const Text(
            'ยอดนี้เป็นบันทึกการจัดสรร ยังไม่ได้ซื้อสินทรัพย์หรือโอนเงินจริง',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
    panel(
      color: const Color(0xFFE8E7E1),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill('กำลังพัฒนา'),
          SizedBox(height: 14),
          SectionTitle(
            'มุมมองการลงทุนระยะยาว',
            subtitle: 'พื้นที่สำหรับทบทวนสินทรัพย์และสัดส่วนในอนาคต',
          ),
        ],
      ),
    ),
  ];

  List<Widget> assistant() => [
    if (messages.isEmpty) ...[
      panel(
        color: const Color(0xFFE6EAD9),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(Icons.forum_outlined, background: surface, size: 52),
            SizedBox(height: 22),
            Text(
              'เข้าใจแผนของคุณ\nทีละคำถาม',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'ถามเรื่องงบความเสี่ยง จุดหยุด หรือการแบ่งกำไร\nผู้ช่วยจะอธิบายจากข้อมูลที่คุณบันทึกไว้',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
      const SectionTitle('เริ่มจากเรื่องที่คุณอยากรู้'),
      ...[
        (Icons.shield_outlined, 'วันนี้เหลืองบความเสี่ยงเท่าไร?'),
        (Icons.pause_circle_outline, 'ผมควรหยุดเทรดหรือยัง?'),
        (Icons.call_split_rounded, 'กำไรวันนี้ควรแบ่งอย่างไร?'),
        (Icons.explore_outlined, 'ตอนนี้แผนของผมเป็นอย่างไร?'),
      ].map(
        (q) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(q.$1, color: green, size: 21),
              title: Text(q.$2, style: const TextStyle(fontSize: 13)),
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: muted,
              ),
              onTap: chatting ? null : () => ask(q.$2),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ],
    ...messages.map(
      (m) => Align(
        alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: panel(
            color: m.user ? mint : surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.user ? 'คุณ' : 'ผู้ช่วยทบทวนแผน',
                  style: const TextStyle(
                    fontSize: 11,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(m.text),
              ],
            ),
          ),
        ),
      ),
    ),
    if (chatting) const LinearProgressIndicator(),
    if (chatError != null)
      Text(chatError!, style: const TextStyle(color: negative)),
    const SizedBox(height: 10),
    TextField(
      controller: chat,
      minLines: 1,
      maxLines: 4,
      enabled: !chatting,
      decoration: InputDecoration(
        hintText: 'พิมพ์คำถามเกี่ยวกับแผน…',
        suffixIcon: IconButton(
          tooltip: 'ส่งคำถาม',
          onPressed: chatting ? null : () => ask(chat.text),
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'ผู้ช่วยใช้กฎจากข้อมูลแผน ยังไม่ได้เชื่อมต่อบริการ AI',
      style: TextStyle(fontSize: 11, color: muted),
    ),
  ];
  Future<void> ask(String q) async {
    if (q.trim().isEmpty || chatting) return;
    setState(() {
      messages.add((user: true, text: q.trim()));
      chatting = true;
      chatError = null;
      chat.clear();
    });
    try {
      final result = await widget.assistantService.reply(
        q,
        InvestmentPlan.fromJson(plan.toJson()),
      );
      if (mounted) setState(() => messages.add((user: false, text: result)));
    } catch (_) {
      if (mounted) {
        setState(() => chatError = 'ผู้ช่วยไม่พร้อม กรุณาลองส่งคำถามอีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => chatting = false);
    }
  }

  Future<void> configure() async {
    final next = await showPlanForm(context, plan);
    if (next != null) await store.replace(next);
  }

  Future<void> recordTrade() async {
    final entry = await showTradeForm(context, plan);
    if (entry != null) {
      await store.commit(
        (p) => p.record(
          entry.asset,
          entry.gross,
          fees: entry.fees,
          time: entry.time,
          note: entry.note,
          strategy: entry.strategy,
        ),
      );
    }
  }

  Future<void> ratios() async {
    final values = await showRatioForm(context, plan);
    if (values != null) {
      await store.commit(
        (p) => p.setAllocation(values[0], values[1], values[2]),
      );
    }
  }

  Future<void> allocate() async {
    final a = plan.preview();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยืนยันการกันกำไร'),
        content: Text(
          'กำไร ${money(a.amount)}\nระยะสั้น ${money(a.short)}\nระยะยาว ${money(a.long)}\nถอน ${money(a.withdraw)}\nบันทึกเท่านั้น ไม่มีการโอนเงิน',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.commit((p) => p.allocate());
  }

  void settings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('ตั้งค่า'),
                ListTile(
                  title: const Text('ข้อมูลการใช้งานและความเสี่ยง'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: c,
                    builder: (d) => AlertDialog(
                      title: const Text('ข้อมูลการใช้งานและความเสี่ยง'),
                      content: const Text(
                        'Tipkhun Capital เป็นเครื่องมือช่วยวางแผนและบริหารความเสี่ยง\nข้อมูลที่แสดงไม่ใช่การรับประกันผลตอบแทน\nผู้ใช้เป็นผู้ตัดสินใจลงทุนด้วยตนเอง',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('ปิด'),
                        ),
                      ],
                    ),
                  ),
                ),
                heading('เกี่ยวกับ Tipkhun Capital'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Brand(full: true),
                ),
                const Text(
                  'Tipkhun Capital กำลังอยู่ระหว่างการพัฒนา\nฟีเจอร์บางส่วนอาจมีการเปลี่ยนแปลงก่อนเปิดตัวอย่างเป็นทางการ',
                ),
                const SizedBox(height: 12),
                const Text(
                  'ข้อมูลเก็บในอุปกรณ์นี้ การล้างข้อมูลแอปหรือถอนการติดตั้งจะลบข้อมูล ยังไม่มี Cloud sync',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
