import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves the screenshots taken by integration_test/screenshots_test.dart to
/// screenshots/ at the package root (shown on pub.dev). Raw PNGs are too big
/// for pub.dev (4 MB max), so on macOS they're saved as 600 px wide JPEGs.
///
///   cd example
///   flutter drive --driver=test_driver/integration_test.dart \
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
