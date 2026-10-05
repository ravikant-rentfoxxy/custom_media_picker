import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/edit_item.dart';
import '../../models/picked_media.dart';
import '../../utils/image_utils.dart';
import 'widgets/text_input_page.dart';
import '../../routes/media_navigation.dart';

enum EditMode { none, draw }

class EditorController extends GetxController {
  final items = <EditItem>[].obs;
  final currentIndex = 0.obs;
  final mode = EditMode.none.obs;
  final drawColor = const Color(0xFFFF3B30).obs;
  final isBusy = false.obs;

  /// True while a finger is on a text label (blocks page swiping).
  final textInteracting = false.obs;
  final draggingText = false.obs;
  final overTrash = false.obs;
  int _textPointers = 0;

  final pageController = PageController();
  final captionController = TextEditingController();

  EditItem get current => items[currentIndex.value];

  bool get pagingLocked => mode.value == EditMode.draw || textInteracting.value;

  @override
  void onInit() {
    super.onInit();
    final inputs = (Get.arguments as List).cast<MediaInput>();
    items.assignAll(inputs.map(EditItem.new));
  }

  // ----------------------------------------------------------------- paging

  void onPageChanged(int index) {
    current.caption = captionController.text;
    currentIndex.value = index;
    captionController.text = current.caption;
  }

  void jumpTo(int index) {
    if (index == currentIndex.value) return;
    pageController.jumpToPage(index);
  }

  void removeItem(int index) {
    if (items.length <= 1) {
      closeRoute();
      return;
    }
    current.caption = captionController.text;
    items.removeAt(index);
    final next = index.clamp(0, items.length - 1);
    currentIndex.value = next;
    captionController.text = current.caption;
    // PageView keeps its own page; resync after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) pageController.jumpToPage(next);
    });
  }

  // ------------------------------------------------------------------- undo

  void undo() {
    final stack = current.undoStack;
    if (stack.isEmpty) return;
    stack.removeLast()();
  }

  // ------------------------------------------------------------------- draw

  void toggleDraw() {
    if (current.isVideo) return;
    mode.value = mode.value == EditMode.draw ? EditMode.none : EditMode.draw;
  }

  void startStroke(EditItem item, Offset normalized) {
    final stroke = DrawStroke(color: drawColor.value, width: kStrokeWidthFactor)
      ..points.add(normalized);
    item.strokes.add(stroke);
    item.undoStack.add(() => item.strokes.remove(stroke));
  }

  void extendStroke(EditItem item, Offset normalized) {
    if (item.strokes.isEmpty) return;
    item.strokes.last.points.add(normalized);
    item.strokes.refresh();
  }

  // ------------------------------------------------------------------- text

  Future<void> addText() async {
    if (current.isVideo) return;
    mode.value = EditMode.none;
    final result = await TextInputPage.open(color: drawColor.value);
    if (result == null || result.text.isEmpty) return;
    drawColor.value = result.color;
    final item = current;
    final overlay = TextOverlay(text: result.text, color: result.color);
    item.texts.add(overlay);
    item.undoStack.add(() => item.texts.remove(overlay));
  }

  Future<void> editText(EditItem item, TextOverlay overlay) async {
    final result = await TextInputPage.open(
      text: overlay.text,
      color: overlay.color,
    );
    if (result == null) return;
    if (result.text.isEmpty) {
      _removeText(item, overlay);
    } else {
      overlay
        ..text = result.text
        ..color = result.color;
      item.texts.refresh();
    }
  }

  void _removeText(EditItem item, TextOverlay overlay) {
    final index = item.texts.indexOf(overlay);
    if (index < 0) return;
    item.texts.removeAt(index);
    item.undoStack.add(
      () => item.texts.insert(index.clamp(0, item.texts.length), overlay),
    );
  }

  void textPointerDown() {
    _textPointers++;
    textInteracting.value = true;
  }

  void textPointerUp() {
    _textPointers = (_textPointers - 1).clamp(0, 99);
    if (_textPointers == 0) textInteracting.value = false;
  }

  void onTextDragUpdate(TextOverlay overlay, Size canvas) {
    draggingText.value = true;
    final p = Offset(
      overlay.position.dx * canvas.width,
      overlay.position.dy * canvas.height,
    );
    overTrash.value =
        p.dy > canvas.height - 90 && (p.dx - canvas.width / 2).abs() < 70;
  }

  void onTextDragEnd(EditItem item, TextOverlay overlay) {
    if (overTrash.value) _removeText(item, overlay);
    draggingText.value = false;
    overTrash.value = false;
  }

  // ------------------------------------------------------------------- crop

  Future<void> openCrop() async {
    mode.value = EditMode.none;
    final item = current;
    if (item.isVideo || isBusy.value) return;
    var base = item.current.value;
    if (item.hasOverlays) {
      isBusy.value = true;
      try {
        base = await ImageUtils.flatten(item);
      } catch (_) {
        Get.snackbar('Error', 'Could not prepare the image for cropping');
        return;
      } finally {
        isBusy.value = false;
      }
    }
    final cropped = await openCropRoute(base);
    if (cropped == null) return;

    final previousFile = item.current.value;
    final previousStrokes = item.strokes.toList();
    final previousTexts = item.texts.toList();
    item.undoStack.add(() {
      item.current.value = previousFile;
      item.strokes.assignAll(previousStrokes);
      item.texts.assignAll(previousTexts);
      item.loadSize();
    });

    // Overlays were baked into the cropped image.
    item.strokes.clear();
    item.texts.clear();
    item.current.value = cropped;
    await item.loadSize();
  }

  // ------------------------------------------------------------------- send

  Future<void> send() async {
    if (isBusy.value) return;
    current.caption = captionController.text;
    isBusy.value = true;
    try {
      final result = <PickedMedia>[];
      for (final item in items) {
        final file = item.hasOverlays
            ? await ImageUtils.flatten(item)
            : item.current.value;
        result.add(
          PickedMedia(
            file: file,
            caption: item.caption.trim(),
            kind: item.input.kind,
            thumbnail: item.input.thumbnail,
            duration: item.input.duration,
          ),
        );
      }
      closeWithResult(result);
    } catch (e) {
      Get.snackbar('Error', 'Could not export image: $e');
    } finally {
      isBusy.value = false;
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    captionController.dispose();
    super.onClose();
  }
}
