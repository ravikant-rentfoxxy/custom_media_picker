import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves the screenshots taken by integration_test/screenshots_test.dart to
/// screenshots/ at the package root (shown on pub.dev). Raw PNGs are too big
/// for pub.dev (4 MB max), so on macOS they're saved as 600 px wide JPEGs.
///
///   cd example
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart
///
/// On an iOS simulator `flutter drive` reinstalls the app, which resets photo
/// access and leaves the system prompt in the way. To keep access, build and
/// install once, allow full photo access the first time it asks, then attach
/// to the running app instead:
///
///   flutter build ios --simulator --debug \
///     -t integration_test/screenshots_test.dart
///   xcrun simctl install booted build/ios/iphonesimulator/Runner.app
///   xcrun simctl launch booted com.example.chatMediaPickerExample
///   # "The Dart VM service is listening on URL" is in the device log.
///   flutter drive --use-existing-app=URL --no-keep-app-running \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final png = File('../screenshots/$name.png');
    await png.create(recursive: true);
    await png.writeAsBytes(bytes);
    if (Platform.isMacOS) {
      final result = await Process.run('sips', [
        '--resampleWidth',
        '600',
        '-s',
        'format',
        'jpeg',
        '-s',
        'formatOptions',
        '82',
        png.path,
        '--out',
        '../screenshots/$name.jpg',
      ]);
      if (result.exitCode == 0) await png.delete();
    }
    return true;
  },
);
