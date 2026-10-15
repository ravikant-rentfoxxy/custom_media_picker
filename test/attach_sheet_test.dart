import 'package:chat_media_picker/chat_media_picker.dart';
import 'package:chat_media_picker/src/modules/gallery/gallery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _photoChannel = MethodChannel('com.fluttercandies/photo_manager');

/// Opacity of the closest [Opacity] above [finder], or null if not found.
double? _opacityOf(Finder finder) {
  final opacity = find.ancestor(of: finder, matching: find.byType(Opacity));
  if (opacity.evaluate().isEmpty) return null;
  return (opacity.evaluate().first.widget as Opacity).opacity;
}

void main() {
  late Future<List<PickedMedia>?> result;

  setUp(() {
    // Photo access denied: the sheet shows its permission message, without
    // reading the library.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_photoChannel, (call) async => 2);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_photoChannel, null);
    ChatMediaPicker.config = const ChatMediaPickerConfig();
  });

  Future<void> open(WidgetTester tester, ChatMediaPickerConfig config) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ChatMediaPicker.config = config;
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox.expand())),
    );
    result = openGallerySheet();
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Get.key.currentState?.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('expands from the options panel to the gallery and back', (
    tester,
  ) async {
    await open(tester, const ChatMediaPickerConfig());

    // Collapsed: options shown, "Recents" title hidden.
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.text('Recents'), findsNothing);

    // "Gallery" expands the sheet: the options crossfade into the title.
    await tester.tap(find.text('Gallery'));
    await tester.pump(const Duration(milliseconds: 120));
    final midTitle = _opacityOf(find.text('Recents'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsNothing);
    expect(_opacityOf(find.text('Recents')), 1);
    if (midTitle != null) expect(midTitle, lessThan(1));

    // A short drag down snaps back to the options panel.
    await tester.timedDrag(
      find.text('Recents'),
      const Offset(0, 300),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Recents'), findsNothing);

    // Dragging the panel down closes the sheet without a result.
    await tester.drag(find.text('Camera'), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('dragging up follows the finger', (tester) async {
    await open(tester, const ChatMediaPickerConfig());
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Camera')),
    );
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    final options = _opacityOf(find.text('Camera'));
    expect(options, isNotNull);
    expect(options, inExclusiveRange(0, 1));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('without gallery the sheet is a compact options panel', (
    tester,
  ) async {
    await open(tester, const ChatMediaPickerConfig(enableGallery: false));
    expect(find.text('Gallery'), findsNothing);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.text('Recents'), findsNothing);
  });

  testWidgets('hides disabled options', (tester) async {
    await open(
      tester,
      const ChatMediaPickerConfig(enableCamera: false, enableFilePicker: false),
    );
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Document'), findsNothing);
  });

  testWidgets('uses the theme colours', (tester) async {
    const theme = ChatMediaPickerTheme.dark();
    await open(tester, const ChatMediaPickerConfig(theme: theme));
    final sheet = tester.widget<Material>(
      find
          .ancestor(of: find.text('Camera'), matching: find.byType(Material))
          .first,
    );
    expect(sheet.color, theme.backgroundColor);
    final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt_rounded));
    expect(icon.color, theme.cameraIconColor);
  });

  testWidgets('the Camera tile is the first cell of the photo grid', (
    tester,
  ) async {
    // Access granted, empty library: the grid holds only the Camera tile.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_photoChannel, (call) async {
          return switch (call.method) {
            'requestPermissionExtend' => 3, // authorized
            'getAssetPathList' => {'data': <Object>[]},
            _ => null,
          };
        });
    await open(tester, const ChatMediaPickerConfig());
    final grid = find.byType(SliverGrid);
    expect(grid, findsOneWidget);
    expect(
      find.descendant(of: grid, matching: find.text('Camera')),
      findsOneWidget,
    );
    await closeSheet(tester);

    // Hidden with the camera disabled.
    await open(tester, const ChatMediaPickerConfig(enableCamera: false));
    expect(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.text('Camera'),
      ),
      findsNothing,
    );
  });

  test('returns null when every option is disabled', () async {
    ChatMediaPicker.config = const ChatMediaPickerConfig(
      enableGallery: false,
      enableCamera: false,
      enableFilePicker: false,
    );
    expect(await openGallerySheet(), isNull);
  });

  test('copyWith keeps the other colours', () {
    const base = ChatMediaPickerTheme();
    final theme = base.copyWith(accentColor: Colors.indigo);
    expect(theme.accentColor, Colors.indigo);
    expect(theme.backgroundColor, base.backgroundColor);
    expect(theme.borderRadius, base.borderRadius);
  });

  test('formatFileSize', () {
    expect(formatFileSize(12), '12 B');
    expect(formatFileSize(640000), '640 kB');
    expect(formatFileSize(1234567), '1.2 MB');
  });
}
