import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/main.dart';
import 'package:superapp/ui/brand_mark.dart';
import 'package:superapp/ui/plan_forms.dart';
import 'package:superapp/domain/investment_plan.dart';

void main() {
  testWidgets('Export brand assets and design previews', (tester) async {
    final font = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    Future<void> save(String path) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final files = [
      ...Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('ic_launcher.png')),
      ...Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
      ...Directory(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
      ...Directory('web')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.png')),
    ];
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final size = ByteData.sublistView(bytes).getUint32(16).toDouble();
      tester.view.physicalSize = Size.square(size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF073C31),
            child: Center(child: BrandMark(size: size * .75)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await save(file.path);
    }
    tester.view.physicalSize = const Size.square(1024);
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const BrandMark(size: 1024)),
    );
    await tester.pumpAndSettle();
    await save('assets/brand/tipkhun-mark.png');
    tester.view.physicalSize = const Size(620, 140);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 80),
                  SizedBox(width: 24),
                  Text(
                    'Tipkhun Capital',
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 36,
                      color: Color(0xFF142E29),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await save('assets/brand/tipkhun-header.png');

    // Windows ICO container with PNG payloads at native icon sizes.
    final iconSizes = [16, 32, 128, 256];
    final payloads = iconSizes
        .map(
          (size) => File(
            'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
          ).readAsBytesSync(),
        )
        .toList();
    final directory = ByteData(6 + 16 * payloads.length)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, payloads.length, Endian.little);
    var offset = directory.lengthInBytes;
    for (var i = 0; i < payloads.length; i++) {
      final base = 6 + 16 * i;
      directory.setUint8(base, iconSizes[i] == 256 ? 0 : iconSizes[i]);
      directory.setUint8(base + 1, iconSizes[i] == 256 ? 0 : iconSizes[i]);
      directory.setUint16(base + 4, 1, Endian.little);
      directory.setUint16(base + 6, 32, Endian.little);
      directory.setUint32(base + 8, payloads[i].length, Endian.little);
      directory.setUint32(base + 12, offset, Endian.little);
      offset += payloads[i].length;
    }
    File('windows/runner/resources/app_icon.ico').writeAsBytesSync([
      ...directory.buffer.asUint8List(),
      for (final payload in payloads) ...payload,
    ]);
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 1050),
    ]) {
      // This executable is run with flutter test to export deterministic previews.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      await tester.pumpWidget(RepaintBoundary(key: key, child: const MyApp()));
      await tester.pumpAndSettle();
      await save('docs/previews/overview-${size.width.toInt()}.png');
      expect(tester.takeException(), isNull);
      for (final entry in {
        'journal': 'บันทึกเทรด',
        'allocation': 'แบ่งกำไร',
        'long-term': 'ระยะยาว',
        'assistant': 'ผู้ช่วย',
      }.entries) {
        await tester.tap(
          find.descendant(
            of: find.byType(size.width >= 850 ? NavigationRail : NavigationBar),
            matching: find.text(entry.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await save('docs/previews/${entry.key}-${size.width.toInt()}.png');
        expect(tester.takeException(), isNull, reason: entry.key);
      }
      for (final form in ['plan', 'trade', 'ratios']) {
        final context = tester.element(find.byType(CapitalHome));
        switch (form) {
          case 'plan':
            showPlanForm(context, InvestmentPlan());
          case 'trade':
            showTradeForm(context, InvestmentPlan());
          case 'ratios':
            showRatioForm(context, InvestmentPlan());
        }
        await tester.pumpAndSettle();
        await save('docs/previews/$form-${size.width.toInt()}.png');
        expect(tester.takeException(), isNull, reason: form);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
