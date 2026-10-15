import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the video badge row of AssetThumbnail (icon + duration).
Widget _badge(double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(
      width: width,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(5, 10, 5, 3),
        child: Row(
          children: [
            Icon(Icons.videocam, size: 16),
            SizedBox(width: 2),
            Expanded(
              child: Text(
                '12:34',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('video badge fits small thumbnails without overflowing', (
    tester,
  ) async {
    for (final width in [30.0, 52.0, 60.0, 100.0]) {
      await tester.pumpWidget(_badge(width));
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
