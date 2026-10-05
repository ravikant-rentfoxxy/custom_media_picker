import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/edit_item.dart';

/// Stroke width relative to the image width.
const double kStrokeWidthFactor = 0.012;

/// Text size relative to the image width (before user scaling).
const double kTextSizeFactor = 0.07;

/// All image processing is done with dart:ui (no third-party image libs).
class ImageUtils {
  ImageUtils._();

  static Future<ui.Image> decode(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Size as Flutter displays it (EXIF orientation applied by the decoder).
  static Future<Size> sizeOf(File file) async {
    final image = await decode(file);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }

  static Future<File> savePng(ui.Image image, {String prefix = 'img'}) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  static TextStyle overlayTextStyle(TextOverlay t, double canvasWidth) {
    return TextStyle(
      color: t.color,
      fontSize: canvasWidth * kTextSizeFactor * t.scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
  }

  static void paintStrokes(Canvas canvas, Size size, List<DrawStroke> strokes) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final pts = s.points
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      if (pts.length == 1) {
        canvas.drawCircle(
          pts.first,
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      // Smooth the line with quadratic curves through mid points.
      for (var i = 1; i < pts.length - 1; i++) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  static void paintText(Canvas canvas, Size size, TextOverlay t) {
    final tp = TextPainter(
      text: TextSpan(text: t.text, style: overlayTextStyle(t, size.width)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(t.position.dx * size.width, t.position.dy * size.height);
    canvas.rotate(t.rotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  /// Bakes strokes and texts into the image at full resolution.
  static Future<File> flatten(EditItem item) async {
    final image = await decode(item.current.value);
    final size = Size(image.width.toDouble(), image.height.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    canvas.clipRect(Offset.zero & size);
    paintStrokes(canvas, size, item.strokes);
    for (final t in item.texts) {
      paintText(canvas, size, t);
    }
    final picture = recorder.endRecording();
    final out = await picture.toImage(image.width, image.height);
    picture.dispose();
    image.dispose();

    final file = await savePng(out, prefix: 'edited');
    out.dispose();
    return file;
  }

  /// Rotates ([quarterTurns] clockwise), optionally mirrors, then crops.
  /// [cropRect] is normalized (0..1) in the rotated + flipped image space.
  static Future<File> cropImage({
    required ui.Image image,
    required int quarterTurns,
    required bool flipHorizontal,
    required Rect cropRect,
  }) async {
    final out = await renderCrop(
      image: image,
      quarterTurns: quarterTurns,
      flipHorizontal: flipHorizontal,
      cropRect: cropRect,
    );
    final file = await savePng(out, prefix: 'cropped');
    out.dispose();
    return file;
  }

  static Future<ui.Image> renderCrop({
    required ui.Image image,
    required int quarterTurns,
    required bool flipHorizontal,
    required Rect cropRect,
  }) async {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final rotated = quarterTurns.isOdd ? Size(h, w) : Size(w, h);

    final crop = Rect.fromLTRB(
      (cropRect.left * rotated.width).roundToDouble(),
      (cropRect.top * rotated.height).roundToDouble(),
      (cropRect.right * rotated.width).roundToDouble(),
      (cropRect.bottom * rotated.height).roundToDouble(),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-crop.left, -crop.top);
    if (flipHorizontal) {
      canvas.translate(rotated.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.translate(rotated.width / 2, rotated.height / 2);
    canvas.rotate(quarterTurns * math.pi / 2);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final out = await picture.toImage(
      math.max(1, crop.width.toInt()),
      math.max(1, crop.height.toInt()),
    );
    picture.dispose();
    return out;
  }
}
