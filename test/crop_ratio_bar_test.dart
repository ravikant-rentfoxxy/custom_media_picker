import 'dart:io';
import 'dart:ui' as ui;

import 'package:chat_media_picker/src/routes/media_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Writes a small PNG to a temp file for the crop screen to open.
Future<File> _tempImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 40, 30),
    Paint()..color = const Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(40, 30);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp('crop_test');
  return File('${dir.path}/image.png')
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Background colour of the pill around [label].
Color? _pillColor(WidgetTester tester, String label) {
  final box = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('ratio options stay readable under a light app chip theme', (
    tester,
  ) async {
    // The kind of host theme that made the options invisible: light chips.
    final hostTheme = ThemeData(
      useMaterial3: true,
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFEFFAF6),
        selectedColor: Color(0xFFEFFAF6),
        labelStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(),
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(theme: hostTheme, home: const Scaffold()),
    );
    final file = (await tester.runAsync(_tempImage))!;
    openCropRoute(file);
    // Let the image decode, then the screen build.
    for (var i = 0; i < 20 && find.text('Free').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Free'), findsOneWidget);
    // "Free" is selected by default: white pill, black text.
    expect(_pillColor(tester, 'Free'), Colors.white);
    expect(tester.widget<Text>(find.text('Free')).style?.color, Colors.black);
    // Unselected: translucent dark pill, white text; not the theme's mint.
    expect(_pillColor(tester, 'Square'), Colors.white12);
    expect(tester.widget<Text>(find.text('Square')).style?.color, Colors.white);

    await tester.tap(find.text('4:3'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_pillColor(tester, '4:3'), Colors.white);
    expect(_pillColor(tester, 'Free'), Colors.white12);
  });
}
