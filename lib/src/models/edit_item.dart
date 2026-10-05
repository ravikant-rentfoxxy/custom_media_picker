import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';

import '../utils/image_utils.dart';
import 'picked_media.dart';

/// A free-hand stroke. Points and width are normalized to the image size
/// (0..1) so the same data can be painted on screen and on the full-res export.
class DrawStroke {
  DrawStroke({required this.color, required this.width});

  final Color color;
  final double width;
  final List<Offset> points = [];
}

/// A movable / scalable / rotatable text label. [position] is the normalized
/// center of the text on the image.
class TextOverlay {
  TextOverlay({
    required this.text,
    required this.color,
    this.position = const Offset(0.5, 0.5),
    this.scale = 1,
    this.rotation = 0,
  });

  String text;
  Color color;
  Offset position;
  double scale;
  double rotation;
}

/// One photo or video in the editor screen. Only photos can be edited
/// (crop / draw / text); videos are previewed and captioned.
class EditItem {
  EditItem(this.input) : current = input.file.obs {
    if (!isVideo) loadSize();
  }

  final MediaInput input;

  bool get isVideo => input.isVideo;

  /// The current base file (for photos, changes after a crop).
  final Rx<File> current;

  /// Pixel size of [current] (null while decoding).
  final Rxn<Size> size = Rxn<Size>();

  final RxList<DrawStroke> strokes = <DrawStroke>[].obs;
  final RxList<TextOverlay> texts = <TextOverlay>[].obs;

  /// Each entry reverts one edit.
  final RxList<VoidCallback> undoStack = <VoidCallback>[].obs;

  String caption = '';

  bool get hasOverlays => strokes.isNotEmpty || texts.isNotEmpty;

  Future<void> loadSize() async {
    size.value = null;
    size.value = await ImageUtils.sizeOf(current.value);
  }
}
