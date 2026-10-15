import 'dart:io';

import 'package:chat_media_picker_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

/// Captures the pub.dev screenshots. Needs a device with photo access granted
/// and some photos in the library; see test_driver/integration_test.dart.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps frames for [ms] (thumbnails load asynchronously and spinners never
  /// settle, so pumpAndSettle can't be used).
  Future<void> wait(WidgetTester tester, [int ms = 1500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await wait(tester, 300);
    await binding.takeScreenshot(name);
  }

  /// Gallery thumbnails: the GestureDetectors of the photo grid.
  Finder tiles() => find.descendant(
    of: find.byType(SliverGrid),
    matching: find.byType(GestureDetector),
  );

  Future<void> openSheet(WidgetTester tester, {bool photos = true}) async {
    await tester.tap(find.byKey(const ValueKey('attach')));
    await wait(tester, 800);
    // Wait for the library to load (the Camera tile is there from the start),
    // then for the thumbnails to decode.
    for (var i = 0; photos && i < 30 && tiles().evaluate().length < 12; i++) {
      await wait(tester, 500);
    }
    await wait(tester, 1500);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Get.key.currentState?.pop();
    await wait(tester, 800);
  }

  /// Toggles an option in the app bar menu.
  Future<void> toggle(WidgetTester tester, String label) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await wait(tester, 600);
    await tester.tap(find.text(label).last);
    await wait(tester, 600);
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.text('Gallery').last);
    await wait(tester, 1500);
  }

  testWidgets('pub.dev screenshots', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await wait(tester);

    await openSheet(tester);

    // Expanded gallery with numbered multi-select.
    await expand(tester);
    await tester.longPress(tiles().at(1));
    await wait(tester, 400);
    await tester.tap(tiles().at(4));
    await wait(tester, 400);
    await tester.tap(tiles().at(6));
    await wait(tester, 800);
    await shot(tester, '2_gallery_multi_select');

    // Editor with a caption.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await wait(tester, 2500);
    await tester.enterText(find.byType(TextField), 'Weekend trip 🏔️');
    await wait(tester, 800);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, 800);
    await shot(tester, '3_editor');

    // Draw mode.
    await tester.tap(find.byIcon(Icons.edit));
    await wait(tester, 600);
    final canvas = tester.getCenter(find.byType(PageView));
    final stroke = await tester.startGesture(canvas - const Offset(100, 60));
    for (var i = 0; i < 20; i++) {
      await stroke.moveBy(Offset(10, i.isEven ? 12 : -6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await stroke.up();
    await wait(tester, 600);
    await shot(tester, '4_editor_draw');
    await tester.tap(find.byIcon(Icons.edit).first);
    await wait(tester, 400);

    // Send: the picked media show up on the example page.
    await tester.tap(find.byIcon(Icons.send));
    await wait(tester, 4000);

    // Collapsed attach panel, over the sent media.
    await openSheet(tester);
    await shot(tester, '1_attach_panel');
    await closeSheet(tester);

    // Dark theme.
    await toggle(tester, 'Dark theme');
    await openSheet(tester);
    await shot(tester, '5_dark_attach_panel');
    await expand(tester);
    await shot(tester, '6_dark_gallery');
    await closeSheet(tester);

    // Gallery disabled: compact options panel.
    await toggle(tester, 'Dark theme');
    await toggle(tester, 'Gallery');
    await openSheet(tester, photos: false);
    await shot(tester, '7_options_only');
    await closeSheet(tester);
  });
}
