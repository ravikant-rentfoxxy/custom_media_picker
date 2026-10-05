import 'dart:ui' as ui;

import 'package:chat_media_picker/src/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2x1 image: left pixel red, right pixel blue.
Future<ui.Image> _redBlue() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(1, 0, 1, 1),
    Paint()..color = const Color(0xFF0000FF),
  );
  return recorder.endRecording().toImage(2, 1);
}

Future<List<int>> _pixels(ui.Image img) async {
  final data = (await img.toByteData())!;
  // High-quality filtering blends edges slightly, so classify each pixel by
  // its dominant channel.
  return [
    for (var i = 0; i < data.lengthInBytes; i += 4)
      data.getUint8(i) > data.getUint8(i + 2) ? red : blue,
  ];
}

const red = 0xFF0000, blue = 0x0000FF;
const full = Rect.fromLTWH(0, 0, 1, 1);

void main() {
  test('no transform keeps image', () async {
    final out = await ImageUtils.renderCrop(
      image: await _redBlue(),
      quarterTurns: 0,
      flipHorizontal: false,
      cropRect: full,
    );
    expect([out.width, out.height], [2, 1]);
    expect(await _pixels(out), [red, blue]);
  });

  test(
    'one clockwise turn puts left side on top (matches RotatedBox)',
    () async {
      final out = await ImageUtils.renderCrop(
        image: await _redBlue(),
        quarterTurns: 1,
        flipHorizontal: false,
        cropRect: full,
      );
      expect([out.width, out.height], [1, 2]);
      expect(await _pixels(out), [red, blue]);
    },
  );

  test('three turns (rotate left) puts left side on bottom', () async {
    final out = await ImageUtils.renderCrop(
      image: await _redBlue(),
      quarterTurns: 3,
      flipHorizontal: false,
      cropRect: full,
    );
    expect(await _pixels(out), [blue, red]);
  });

  test('horizontal flip mirrors', () async {
    final out = await ImageUtils.renderCrop(
      image: await _redBlue(),
      quarterTurns: 0,
      flipHorizontal: true,
      cropRect: full,
    );
    expect(await _pixels(out), [blue, red]);
  });

  test('crop right half', () async {
    final out = await ImageUtils.renderCrop(
      image: await _redBlue(),
      quarterTurns: 0,
      flipHorizontal: false,
      cropRect: const Rect.fromLTWH(0.5, 0, 0.5, 1),
    );
    expect([out.width, out.height], [1, 1]);
    expect(await _pixels(out), [blue]);
  });

  test('rotate then crop bottom half', () async {
    final out = await ImageUtils.renderCrop(
      image: await _redBlue(),
      quarterTurns: 1,
      flipHorizontal: false,
      cropRect: const Rect.fromLTWH(0, 0.5, 1, 0.5),
    );
    expect(await _pixels(out), [blue]);
  });
}
