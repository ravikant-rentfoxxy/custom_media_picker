import 'dart:async';
import 'dart:ui' as ui;

import 'package:chat_media_picker/chat_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end checks of the picker on a device: sheet, gallery, editor, crop,
/// camera and options. Needs photo (and camera) access and a library with a
/// few photos; the video check is skipped when the visible grid has no video.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, [int ms = 600]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Grid cells: index 0 is the Camera tile (when enabled), then the photos.
  Finder tiles() => find.descendant(
    of: find.byType(SliverGrid),
    matching: find.byType(GestureDetector),
  );

  /// Grid cells showing a video (they have a camera badge).
  Finder videoTiles() => find.ancestor(
    of: find.descendant(
      of: find.byType(SliverGrid),
      matching: find.byIcon(Icons.videocam),
    ),
    matching: find.byType(GestureDetector),
  );

  /// Index in [tiles] of the [n]th photo (skipping the Camera tile and
  /// videos).
  int photoIndex(WidgetTester tester, int n, {bool cameraTile = true}) {
    final videos = videoTiles().evaluate().map((e) => e.widget).toSet();
    var seen = 0;
    final cells = tiles().evaluate().toList();
    for (var i = cameraTile ? 1 : 0; i < cells.length; i++) {
      if (videos.contains(cells[i].widget)) continue;
      if (seen++ == n) return i;
    }
    throw StateError('not enough photos in the grid');
  }

  /// The camera screen's shutter button.
  Finder shutter() => find.byWidgetPredicate(
    (w) => w is Container && w.constraints?.maxWidth == 84,
    description: 'shutter',
  );

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox.expand())),
    );
    await wait(tester, 300);
  }

  /// Opens the sheet and waits for the photos.
  Future<Future<List<PickedMedia>?>> openSheet(
    WidgetTester tester,
    ChatMediaPickerConfig config, {
    bool photos = true,
  }) async {
    final result = ChatMediaPicker.openGallery(config: config);
    await wait(tester, 800);
    for (var i = 0; photos && i < 40 && tiles().evaluate().length < 6; i++) {
      await wait(tester, 250);
    }
    await wait(tester, 500);
    return result;
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.text('Gallery').last);
    await wait(tester, 1000);
  }

  Future<T> settle<T>(WidgetTester tester, Future<T> future) async {
    T? value;
    var done = false;
    unawaited(
      future.then((v) {
        value = v;
        done = true;
      }),
    );
    for (var i = 0; i < 100 && !done; i++) {
      await wait(tester, 100);
    }
    expect(done, isTrue, reason: 'picker did not return');
    // Let closing animations finish before the test ends.
    await wait(tester, 1000);
    return value as T;
  }

  Future<ui.Image> decode(WidgetTester tester, PickedMedia media) async {
    return (await tester.runAsync(
      () async => decodeImageFromList(await media.file.readAsBytes()),
    ))!;
  }

  // With `flutter drive --use-existing-app` the driver attaches after launch
  // and turns semantics on; give it time before the first real check.
  testWidgets('wait for the driver', (tester) async {
    await start(tester);
    await wait(tester, 8000);
  });

  testWidgets('sheet: options, Camera tile, close button', (tester) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    for (final label in ['Gallery', 'Camera', 'Document']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    final cameraTile = find.descendant(
      of: find.byType(SliverGrid),
      matching: find.text('Camera'),
    );
    expect(cameraTile, findsOneWidget);
    expect(tiles().evaluate().length, greaterThan(4));

    await tester.tap(find.byTooltip('Close'));
    expect(await settle(tester, result), isNull);
  });

  testWidgets('gallery: expand, album switcher, collapse', (tester) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await expand(tester);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);

    // Album list.
    await tester.tap(find.text('Recents'));
    await wait(tester, 1500);
    final albums = find.byType(ListTile);
    expect(albums, findsWidgets);
    expect(find.textContaining('items'), findsWidgets);
    await tester.tap(albums.first);
    await wait(tester, 1200);
    expect(tiles().evaluate().length, greaterThan(1));

    // Drag back down to the options panel.
    await tester.timedDrag(
      find.byIcon(Icons.arrow_drop_down),
      const Offset(0, 300),
      const Duration(milliseconds: 800),
    );
    await wait(tester, 1000);
    expect(find.text('Document'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    expect(await settle(tester, result), isNull);
  });

  testWidgets('gallery: selection limit and multi-select toggle', (
    tester,
  ) async {
    await start(tester);
    final result = await openSheet(
      tester,
      const ChatMediaPickerConfig(maxSelection: 2),
    );
    await expand(tester);
    await tester.longPress(tiles().at(photoIndex(tester, 0)));
    await wait(tester, 300);
    await tester.tap(tiles().at(photoIndex(tester, 1)));
    await wait(tester, 300);
    await tester.tap(tiles().at(photoIndex(tester, 2)));
    await wait(tester, 500);
    expect(find.text('You can only share up to 2 photos'), findsOneWidget);
    expect(find.text('2 of 2 selected'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);

    // Turning multi-select off clears the selection.
    await tester.tap(find.byIcon(Icons.filter_none));
    await wait(tester, 2500); // Let the snackbar go.
    expect(find.text('2 of 2 selected'), findsNothing);
    expect(find.text('Recents'), findsOneWidget);

    Get.key.currentState?.pop();
    expect(await settle(tester, result), isNull);
  });

  testWidgets('video: returned with thumbnail and duration', (tester) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await expand(tester);
    if (videoTiles().evaluate().isEmpty) {
      Get.key.currentState?.pop();
      await settle(tester, result);
      markTestSkipped('no video among the visible items');
      return;
    }
    await tester.tap(videoTiles().first);
    await wait(tester, 3000);
    expect(find.byIcon(Icons.send), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    expect(media, hasLength(1));
    expect(media.first.isVideo, isTrue);
    expect(media.first.thumbnail, isNotNull);
    expect(media.first.duration, greaterThan(Duration.zero));
    expect(media.first.file.existsSync(), isTrue);
  });

  testWidgets('editor: text, crop square + rotate + flip, caption', (
    tester,
  ) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await expand(tester);
    await tester.tap(tiles().at(photoIndex(tester, 0)));
    await wait(tester, 2500);

    // Text overlay.
    await tester.tap(find.byTooltip('Text'));
    await wait(tester, 800);
    await tester.enterText(find.byType(TextField).last, 'Hello');
    await wait(tester, 300);
    await tester.tap(find.text('Done'));
    await wait(tester, 1000);
    expect(find.text('Hello'), findsOneWidget);

    // Crop to a square, rotate and flip.
    await tester.tap(find.byTooltip('Crop & rotate'));
    await wait(tester, 2000);
    expect(find.text('Square'), findsOneWidget);
    await tester.tap(find.text('Square'));
    await wait(tester, 400);
    await tester.tap(find.byTooltip('Rotate'));
    await wait(tester, 400);
    await tester.tap(find.byTooltip('Flip'));
    await wait(tester, 400);
    await tester.tap(find.text('Done'));
    await wait(tester, 3000);

    await tester.enterText(find.byType(TextField), 'Caption 1');
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, 600);
    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    expect(media, hasLength(1));
    final picked = media.first;
    expect(picked.caption, 'Caption 1');
    expect(picked.isVideo, isFalse);
    expect(picked.file.existsSync(), isTrue);
    final image = await decode(tester, picked);
    expect(image.width, image.height, reason: 'square crop');
  });

  testWidgets('editor: draw then undo returns the original photo', (
    tester,
  ) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await expand(tester);
    await tester.tap(tiles().at(photoIndex(tester, 1)));
    await wait(tester, 2500);

    await tester.tap(find.byTooltip('Draw'));
    await wait(tester, 500);
    final center = tester.getCenter(find.byType(PageView));
    final stroke = await tester.startGesture(center);
    for (var i = 0; i < 10; i++) {
      await stroke.moveBy(const Offset(12, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await stroke.up();
    await wait(tester, 400);
    await tester.tap(find.byTooltip('Undo'));
    await wait(tester, 400);
    await tester.tap(find.text('Done'));
    await wait(tester, 500);

    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    // No overlays left: the untouched file, not a flattened PNG.
    expect(media.single.file.path.toLowerCase().endsWith('.png'), isFalse);
  });

  testWidgets('editor: several photos, remove one, caption each', (
    tester,
  ) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await expand(tester);
    await tester.longPress(tiles().at(photoIndex(tester, 0)));
    await wait(tester, 300);
    await tester.tap(tiles().at(photoIndex(tester, 1)));
    await wait(tester, 300);
    await tester.tap(tiles().at(photoIndex(tester, 2)));
    await wait(tester, 500);
    expect(find.text('3 of 10 selected'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await wait(tester, 3000);

    // Tapping the selected thumbnail removes it.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await wait(tester, 1000);
    Finder thumbs() => find.byWidgetPredicate(
      // The strip decodes at 180 px wide; the editor canvas uses its own
      // size.
      (w) =>
          w is Image &&
          w.image is ResizeImage &&
          (w.image as ResizeImage).width == 180,
      description: 'editor thumbnails',
    );
    expect(thumbs(), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'A');
    await wait(tester, 300);
    // Jump to the thumbnail that isn't selected (no delete icon on it).
    final selectedX = tester.getCenter(find.byIcon(Icons.delete_outline)).dx;
    final other = thumbs().evaluate().firstWhere(
      (e) =>
          (tester.getCenter(find.byWidget(e.widget)).dx - selectedX).abs() > 20,
    );
    await tester.tap(find.byWidget(other.widget));
    await wait(tester, 1200);
    await tester.enterText(find.byType(TextField), 'B');
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, 600);

    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    expect(media, hasLength(2));
    expect(media.map((m) => m.caption).toSet(), {'A', 'B'});
  });

  testWidgets('camera: take a photo and send it', (tester) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    // Camera tile in the grid.
    await tester.tap(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.text('Camera'),
      ),
    );
    await wait(tester, 4000);
    if (find.byIcon(Icons.no_photography).evaluate().isNotEmpty) {
      // Simulator: no camera. The fallback screen must still allow closing.
      debugPrint('CHECK: no camera on this device, fallback screen shown');
      await tester.tap(find.byIcon(Icons.close).first);
      await wait(tester, 1000);
      Get.key.currentState?.pop();
      expect(await settle(tester, result), isNull);
      return;
    }
    expect(shutter(), findsOneWidget);
    await tester.tap(shutter());
    await wait(tester, 5000);
    expect(find.byIcon(Icons.send), findsOneWidget, reason: 'editor opened');
    await tester.enterText(find.byType(TextField), 'From camera');
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, 600);
    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    expect(media, hasLength(1));
    expect(media.first.caption, 'From camera');
    expect(media.first.file.existsSync(), isTrue);
    final image = await decode(tester, media.first);
    expect(image.width, greaterThan(100));
  });

  testWidgets('camera: gallery button opens the gallery without options', (
    tester,
  ) async {
    await start(tester);
    final result = ChatMediaPicker.openCamera(
      config: const ChatMediaPickerConfig(),
    );
    await wait(tester, 4000);
    await tester.tap(find.byIcon(Icons.photo_outlined));
    await wait(tester, 2500);
    for (var i = 0; i < 20 && tiles().evaluate().length < 4; i++) {
      await wait(tester, 250);
    }
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Document'), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
    // No Camera tile here.
    expect(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.text('Camera'),
      ),
      findsNothing,
    );
    await tester.tap(tiles().at(photoIndex(tester, 0, cameraTile: false)));
    await wait(tester, 2500);
    await tester.tap(find.byIcon(Icons.send));
    final media = (await settle(tester, result))!;
    expect(media, hasLength(1));
    expect(media.first.isVideo, isFalse);
  });

  testWidgets('camera: closing returns to the sheet', (tester) async {
    await start(tester);
    final result = await openSheet(tester, const ChatMediaPickerConfig());
    await tester.tap(find.text('Camera').first); // The option chip.
    await wait(tester, 4000);
    await tester.tap(find.byIcon(Icons.close).first);
    await wait(tester, 1500);
    expect(find.text('Document'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(await settle(tester, result), isNull);
  });

  testWidgets('options: gallery, camera and files can be turned off', (
    tester,
  ) async {
    await start(tester);
    var result = await openSheet(
      tester,
      const ChatMediaPickerConfig(enableGallery: false),
      photos: false,
    );
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(await settle(tester, result), isNull);

    result = await openSheet(
      tester,
      const ChatMediaPickerConfig(enableCamera: false, enableFilePicker: false),
    );
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Document'), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(await settle(tester, result), isNull);

    final none = ChatMediaPicker.openGallery(
      config: const ChatMediaPickerConfig(
        enableGallery: false,
        enableCamera: false,
        enableFilePicker: false,
      ),
    );
    expect(await settle(tester, none), isNull);
  });

  testWidgets('document: opens the system file picker', (tester) async {
    await start(tester);
    await openSheet(tester, const ChatMediaPickerConfig());
    await tester.tap(find.text('Document'));
    // The native picker is outside Flutter; checked with a device screenshot.
    debugPrint('CHECK: file picker should be on screen now');
    await wait(tester, 8000);
    // The picker stays open until the user leaves it; the test ends here.
  });
}
