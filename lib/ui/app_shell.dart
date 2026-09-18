import 'package:flutter/material.dart';
import 'brand_mark.dart';
import 'design_tokens.dart';

abstract final class Breakpoints {
  static const mobile = 600.0;
  static const desktop = 1024.0;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

class ResponsivePageContainer extends StatelessWidget {
  const ResponsivePageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1440,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.page,
    required this.onNavigate,
    required this.child,
    required this.onSettings,
  });
  final int page;
  final ValueChanged<int> onNavigate;
  final VoidCallback onSettings;
  final Widget child;
  static const labels = [
    'ภาพรวม',
    'บันทึกเทรด',
    'แบ่งกำไร',
    'ระยะยาว',
    'ผู้ช่วย',
    'Trading Bot',
    'Risk Analytics',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.call_split,
    Icons.account_balance_outlined,
    Icons.chat_bubble_outline,
    Icons.smart_toy_outlined,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];
  void info(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final desktop = Breakpoints.isDesktop(context);
    final destinations = [0, 5, 1, 2, 3, 4, 6, 7];
    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              title: const Row(
                children: [
                  BrandMark(),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Tipkhun Capital',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: onSettings,
                  tooltip: 'ตั้งค่า',
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (desktop)
              SizedBox(
                width: 236,
                child: ColoredBox(
                  color: charcoal,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(22),
                        child: Row(
                          children: [
                            BrandMark(),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tipkhun Capital',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 540),
                            child: IntrinsicHeight(
                              child: NavigationRail(
                                extended: true,
                                minExtendedWidth: 236,
                                selectedIndex: destinations
                                    .indexOf(page >= 8 ? 5 : page)
                                    .clamp(0, 7),
                                onDestinationSelected: (i) =>
                                    onNavigate(destinations[i]),
                                destinations: [
                                  for (final i in destinations)
                                    NavigationRailDestination(
                                      icon: Icon(icons[i]),
                                      label: Text(labels[i]),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'LOCAL WORKSPACE\nไม่มีการซิงค์ข้ามอุปกรณ์',
                          style: TextStyle(color: railText, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (desktop)
                    Material(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'บัญชีในอุปกรณ์นี้',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              page == 5 || page >= 8
                                  ? 'Paper · Mock Broker'
                                  : 'Simulation / Planning',
                            ),
                            const SizedBox(width: 16),
                            const Tooltip(
                              message: 'ยังไม่เชื่อมต่อ Backend หรือโบรกเกอร์',
                              child: Icon(
                                Icons.cloud_off_outlined,
                                color: muted,
                              ),
                            ),
                            IconButton(
                              tooltip: 'การแจ้งเตือน',
                              onPressed: () => info(
                                context,
                                'การแจ้งเตือน',
                                'ยังไม่มีบริการแจ้งเตือนจาก Server ดูเหตุการณ์จำลองใน Bot Logs',
                              ),
                              icon: const Icon(Icons.notifications_none),
                            ),
                            IconButton(
                              tooltip: 'บัญชีและโปรไฟล์',
                              onPressed: () => info(
                                context,
                                'บัญชีในอุปกรณ์นี้',
                                'ยังไม่มีระบบเข้าสู่ระบบหรือ Cloud Sync ข้อมูลอยู่ใน browser/device นี้',
                              ),
                              icon: const Icon(Icons.account_circle_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: page >= 5 || page < 0 ? 0 : page,
              onDestinationSelected: onNavigate,
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 10),
              ),
              destinations: [
                for (var i = 0; i < 5; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}
