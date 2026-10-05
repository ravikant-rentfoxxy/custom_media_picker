import 'dart:io';
import 'dart:ui' as ui;

import 'package:chat_media_picker/chat_media_picker.dart';
import 'package:chat_media_picker/src/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF00FF00),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = await Directory.systemTemp.createTemp('cmp_test');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/img.png')
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('sizeOf keeps the aspect ratio of a large image', () async {
    final size = await ImageUtils.sizeOf(await _png(1200, 800));
    expect(size.aspectRatio, closeTo(1.5, 0.01));
  });

  test('sizeOf keeps the aspect ratio of a portrait image', () async {
    final size = await ImageUtils.sizeOf(await _png(300, 900));
    expect(size.aspectRatio, closeTo(1 / 3, 0.01));
  });

  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 7)), '1:00:07');
  });
}
