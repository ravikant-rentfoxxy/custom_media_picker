import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/image_utils.dart';
import '../../routes/media_navigation.dart';

class CropRatio {
  const CropRatio(this.label, this.value);

  final String label;

  /// width / height, null = free.
  final double? value;
}

enum CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  top,
  right,
  bottom,
  move,
}

class CropController extends GetxController {
  static const ratios = <CropRatio>[
    CropRatio('Free', null),
    CropRatio('Square', 1),
    CropRatio('3:4', 3 / 4),
    CropRatio('4:3', 4 / 3),
    CropRatio('9:16', 9 / 16),
    CropRatio('16:9', 16 / 9),
  ];

  /// Minimum crop side on screen, in logical pixels.
  static const minSide = 60.0;

  late final File file;
  final image = Rxn<ui.Image>();
  final quarterTurns = 0.obs;
  final flipHorizontal = false.obs;
  final ratio = Rxn<double>();

  /// Crop rect normalized (0..1) against the rotated + flipped image.
  final cropRect = const Rect.fromLTWH(0, 0, 1, 1).obs;
  final isSaving = false.obs;

  // Drag state (in display pixels).
  CropHandle? _handle;
  Rect _startRect = Rect.zero;
  Offset _startPoint = Offset.zero;

  @override
  void onInit() {
    super.onInit();
    file = Get.arguments as File;
    _load();
  }

  Future<void> _load() async {
    try {
      final img = await ImageUtils.decode(file);
      // Closed while decoding: onClose had nothing to dispose yet.
      if (isClosed) {
        img.dispose();
      } else {
        image.value = img;
      }
    } catch (_) {
      if (isClosed) return;
      closeRoute();
      Get.snackbar('Error', 'Could not open this image for cropping');
    }
  }

  /// Image size after rotation, in pixels.
  Size get rotatedSize {
    final img = image.value!;
    final w = img.width.toDouble(), h = img.height.toDouble();
    return quarterTurns.value.isOdd ? Size(h, w) : Size(w, h);
  }

  bool get isChanged =>
      quarterTurns.value != 0 ||
      flipHorizontal.value ||
      cropRect.value != const Rect.fromLTWH(0, 0, 1, 1);

  void rotateLeft() {
    quarterTurns.value = (quarterTurns.value + 3) % 4;
    _fitCropToRatio();
  }

  void flip() {
    flipHorizontal.toggle();
    final r = cropRect.value;
    cropRect.value = Rect.fromLTRB(1 - r.right, r.top, 1 - r.left, r.bottom);
  }

  void setRatio(double? value) {
    ratio.value = value;
    _fitCropToRatio();
  }

  void reset() {
    quarterTurns.value = 0;
    flipHorizontal.value = false;
    ratio.value = null;
    cropRect.value = const Rect.fromLTWH(0, 0, 1, 1);
  }

  /// Largest centered rect with the selected ratio.
  void _fitCropToRatio() {
    final r = ratio.value;
    if (r == null || image.value == null) {
      cropRect.value = const Rect.fromLTWH(0, 0, 1, 1);
      return;
    }
    final size = rotatedSize;
    var w = 1.0;
    var h = (size.width / r) / size.height;
    if (h > 1) {
      h = 1;
      w = (size.height * r) / size.width;
    }
    cropRect.value = Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
  }

  // ---------------------------------------------------------------- gestures

  void onPanStart(Offset point, Size display) {
    final rect = _toDisplay(cropRect.value, display);
    _handle = _hitTest(rect, point);
    _startRect = rect;
    _startPoint = point;
  }

  void onPanUpdate(Offset point, Size display) {
    final handle = _handle;
    if (handle == null) return;
    final delta = point - _startPoint;
    final bounds = Offset.zero & display;
    final r = ratio.value;

    Rect next;
    if (handle == CropHandle.move) {
      next = _startRect.shift(delta);
      final dx = next.left < 0
          ? -next.left
          : (next.right > bounds.right ? bounds.right - next.right : 0.0);
      final dy = next.top < 0
          ? -next.top
          : (next.bottom > bounds.bottom ? bounds.bottom - next.bottom : 0.0);
      next = next.shift(Offset(dx, dy));
    } else if (r != null) {
      // The display box has the image's aspect, so pixel ratio == screen ratio.
      next = _resizeLocked(handle, delta, display, r);
    } else {
      next = _resizeFree(handle, delta, bounds);
    }
    cropRect.value = _toNormalized(next, display);
  }

  void onPanEnd() => _handle = null;

  CropHandle? _hitTest(Rect rect, Offset p) {
    const touch = 32.0;
    bool near(Offset a) => (a - p).distance < touch;
    if (near(rect.topLeft)) return CropHandle.topLeft;
    if (near(rect.topRight)) return CropHandle.topRight;
    if (near(rect.bottomLeft)) return CropHandle.bottomLeft;
    if (near(rect.bottomRight)) return CropHandle.bottomRight;
    if (ratio.value == null) {
      final inY = p.dy > rect.top && p.dy < rect.bottom;
      final inX = p.dx > rect.left && p.dx < rect.right;
      if (inY && (p.dx - rect.left).abs() < touch) return CropHandle.left;
      if (inY && (p.dx - rect.right).abs() < touch) return CropHandle.right;
      if (inX && (p.dy - rect.top).abs() < touch) return CropHandle.top;
      if (inX && (p.dy - rect.bottom).abs() < touch) return CropHandle.bottom;
    }
    if (rect.contains(p)) return CropHandle.move;
    return null;
  }

  Rect _resizeFree(CropHandle h, Offset d, Rect bounds) {
    final s = _startRect;
    var left = s.left, top = s.top, right = s.right, bottom = s.bottom;
    if (h == CropHandle.left ||
        h == CropHandle.topLeft ||
        h == CropHandle.bottomLeft) {
      left = (s.left + d.dx).clamp(bounds.left, right - minSide);
    }
    if (h == CropHandle.right ||
        h == CropHandle.topRight ||
        h == CropHandle.bottomRight) {
      right = (s.right + d.dx).clamp(left + minSide, bounds.right);
    }
    if (h == CropHandle.top ||
        h == CropHandle.topLeft ||
        h == CropHandle.topRight) {
      top = (s.top + d.dy).clamp(bounds.top, bottom - minSide);
    }
    if (h == CropHandle.bottom ||
        h == CropHandle.bottomLeft ||
        h == CropHandle.bottomRight) {
      bottom = (s.bottom + d.dy).clamp(top + minSide, bounds.bottom);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Corner resize keeping [r] (width / height in display pixels); the
  /// opposite corner stays anchored.
  Rect _resizeLocked(CropHandle h, Offset d, Size display, double r) {
    final s = _startRect;
    final isLeft = h == CropHandle.topLeft || h == CropHandle.bottomLeft;
    final isTop = h == CropHandle.topLeft || h == CropHandle.topRight;
    final anchor = Offset(isLeft ? s.right : s.left, isTop ? s.bottom : s.top);

    final proposedW = s.width + (isLeft ? -d.dx : d.dx);
    final proposedH = s.height + (isTop ? -d.dy : d.dy);
    var w = math.max(proposedW, proposedH * r);

    final maxW = isLeft ? anchor.dx : display.width - anchor.dx;
    final maxH = isTop ? anchor.dy : display.height - anchor.dy;
    final upper = math.min(maxW, maxH * r);
    final lower = math.min(math.max(minSide, minSide * r), upper);
    w = w.clamp(lower, upper);
    final hgt = w / r;

    final left = isLeft ? anchor.dx - w : anchor.dx;
    final top = isTop ? anchor.dy - hgt : anchor.dy;
    return Rect.fromLTWH(left, top, w, hgt);
  }

  Rect _toDisplay(Rect n, Size d) => Rect.fromLTRB(
    n.left * d.width,
    n.top * d.height,
    n.right * d.width,
    n.bottom * d.height,
  );

  Rect _toNormalized(Rect r, Size d) => Rect.fromLTRB(
    (r.left / d.width).clamp(0, 1),
    (r.top / d.height).clamp(0, 1),
    (r.right / d.width).clamp(0, 1),
    (r.bottom / d.height).clamp(0, 1),
  );

  // ------------------------------------------------------------------ output

  Future<void> done() async {
    final img = image.value;
    if (img == null || isSaving.value) return;
    if (!isChanged) {
      closeRoute();
      return;
    }
    isSaving.value = true;
    try {
      final out = await ImageUtils.cropImage(
        image: img,
        quarterTurns: quarterTurns.value,
        flipHorizontal: flipHorizontal.value,
        cropRect: cropRect.value,
      );
      closeWithResult(out);
    } catch (_) {
      Get.snackbar('Error', 'Could not save the cropped image');
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    image.value?.dispose();
    super.onClose();
  }
}
