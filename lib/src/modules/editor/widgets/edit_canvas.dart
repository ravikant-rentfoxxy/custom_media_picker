import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/edit_item.dart';
import '../../../utils/image_utils.dart';
import '../editor_controller.dart';

/// Shows one image with its strokes and texts, and handles drawing / text
/// gestures. Every coordinate is stored normalized to the image size so the
/// export (ImageUtils.flatten) paints exactly what is shown.
class EditCanvas extends GetView<EditorController> {
  const EditCanvas({super.key, required this.item});

  final EditItem item;

  @override
  Widget build(BuildContext context) {
    // Decode at screen resolution, not camera resolution. Based on the screen
    // (not the canvas) so the keyboard resizing the canvas doesn't re-decode.
    final screen = MediaQuery.sizeOf(context);
    final cacheWidth =
        (screen.longestSide * MediaQuery.devicePixelRatioOf(context)).round();
    return LayoutBuilder(
      builder: (context, constraints) => Obx(() {
        final size = item.size.value;
        final file = item.current.value;
        if (item.loadFailed.value) {
          return const Center(
            child: Text(
              'Could not load this image',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        if (size == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final canvas = applyBoxFit(
          BoxFit.contain,
          size,
          constraints.biggest,
        ).destination;
        Offset norm(Offset p) => Offset(
          (p.dx / canvas.width).clamp(0.0, 1.0),
          (p.dy / canvas.height).clamp(0.0, 1.0),
        );

        return Center(
          child: SizedBox.fromSize(
            size: canvas,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    file,
                    fit: BoxFit.fill,
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: Obx(
                      () => CustomPaint(
                        painter: _StrokesPainter(
                          item.strokes.toList(),
                          // Changes on every new point so the painter repaints.
                          item.strokes.fold<int>(
                            0,
                            (sum, s) => sum + s.points.length,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: Obx(
                      () => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final t in item.texts.toList())
                            _TextLabel(
                              key: ObjectKey(t),
                              item: item,
                              overlay: t,
                              canvas: canvas,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Obx(() {
                  final isCurrent =
                      controller.items.isNotEmpty && controller.current == item;
                  if (controller.mode.value != EditMode.draw || !isCurrent) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) =>
                          controller.startStroke(item, norm(d.localPosition)),
                      onPanUpdate: (d) =>
                          controller.extendStroke(item, norm(d.localPosition)),
                    ),
                  );
                }),
                Obx(
                  () =>
                      controller.draggingText.value &&
                          controller.current == item
                      ? Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: EdgeInsets.all(
                                controller.overTrash.value ? 16 : 12,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controller.overTrash.value
                                    ? Colors.red
                                    : Colors.black54,
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes, this.pointCount);

  final List<DrawStroke> strokes;
  final int pointCount;

  @override
  void paint(Canvas canvas, Size size) =>
      ImageUtils.paintStrokes(canvas, size, strokes);

  @override
  bool shouldRepaint(covariant _StrokesPainter old) =>
      old.pointCount != pointCount || old.strokes.length != strokes.length;
}

/// A text label that can be dragged, pinched (scale) and rotated.
class _TextLabel extends StatefulWidget {
  const _TextLabel({
    super.key,
    required this.item,
    required this.overlay,
    required this.canvas,
  });

  final EditItem item;
  final TextOverlay overlay;
  final Size canvas;

  @override
  State<_TextLabel> createState() => _TextLabelState();
}

class _TextLabelState extends State<_TextLabel> {
  final _controller = Get.find<EditorController>();
  double _baseScale = 1;
  double _baseRotation = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.overlay;
    final canvas = widget.canvas;
    return Positioned(
      left: t.position.dx * canvas.width,
      top: t.position.dy * canvas.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Listener(
          onPointerDown: (_) => _controller.textPointerDown(),
          onPointerUp: (_) => _controller.textPointerUp(),
          onPointerCancel: (_) => _controller.textPointerUp(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _controller.editText(widget.item, t),
            onScaleStart: (_) {
              _baseScale = t.scale;
              _baseRotation = t.rotation;
            },
            onScaleUpdate: (d) {
              t.position = Offset(
                (t.position.dx + d.focalPointDelta.dx / canvas.width).clamp(
                  0.0,
                  1.0,
                ),
                (t.position.dy + d.focalPointDelta.dy / canvas.height).clamp(
                  0.0,
                  1.0,
                ),
              );
              if (d.pointerCount > 1) {
                t.scale = (_baseScale * d.scale).clamp(0.3, 6.0);
                t.rotation = _baseRotation + d.rotation;
              }
              widget.item.texts.refresh();
              _controller.onTextDragUpdate(t, canvas);
            },
            onScaleEnd: (_) => _controller.onTextDragEnd(widget.item, t),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Transform.rotate(
                angle: t.rotation,
                child: Text(
                  t.text,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: ImageUtils.overlayTextStyle(t, canvas.width),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
