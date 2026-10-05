import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/media_navigation.dart';
import 'crop_controller.dart';

class CropView extends GetView<CropController> {
  const CropView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(controller: controller),
            const Expanded(child: _CropArea()),
            const _RatioBar(),
            _BottomBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: closeRoute,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Flip',
          icon: const Icon(Icons.flip, color: Colors.white),
          onPressed: controller.flip,
        ),
        IconButton(
          tooltip: 'Rotate',
          icon: const Icon(Icons.rotate_90_degrees_ccw, color: Colors.white),
          onPressed: controller.rotateLeft,
        ),
      ],
    );
  }
}

class _CropArea extends GetView<CropController> {
  const _CropArea();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Obx(() {
        final image = controller.image.value;
        if (image == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final turns = controller.quarterTurns.value;
        final flip = controller.flipHorizontal.value;
        final crop = controller.cropRect.value;

        const padding = 24.0;
        final available = Size(
          constraints.maxWidth - padding * 2,
          constraints.maxHeight - padding * 2,
        );
        final display = applyBoxFit(
          BoxFit.contain,
          controller.rotatedSize,
          available,
        ).destination;

        return Center(
          child: SizedBox.fromSize(
            size: display,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) =>
                  controller.onPanStart(d.localPosition, display),
              onPanUpdate: (d) =>
                  controller.onPanUpdate(d.localPosition, display),
              onPanEnd: (_) => controller.onPanEnd(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Transform.flip(
                      flipX: flip,
                      child: RotatedBox(
                        quarterTurns: turns,
                        child: RawImage(image: image, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        rect: Rect.fromLTRB(
                          crop.left * display.width,
                          crop.top * display.height,
                          crop.right * display.width,
                          crop.bottom * display.height,
                        ),
                        showEdgeHandles: controller.ratio.value == null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RatioBar extends GetView<CropController> {
  const _RatioBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Obx(() {
        final current = controller.ratio.value;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final r in CropController.ratios)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(r.label),
                  selected: current == r.value,
                  onSelected: (_) => controller.setRatio(r.value),
                  showCheckmark: false,
                  backgroundColor: Colors.white10,
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(
                    color: current == r.value ? Colors.black : Colors.white,
                  ),
                  side: BorderSide.none,
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: controller.reset,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
          const Spacer(),
          Obx(
            () => controller.isSaving.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: controller.done,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.rect, required this.showEdgeHandles});

  final Rect rect;
  final bool showEdgeHandles;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim outside of the crop area.
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(outside, Paint()..color = Colors.black54);

    // Rule-of-thirds grid.
    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }

    // Border.
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Corner handles.
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const len = 22.0;
    void corner(Offset p, double dx, double dy) {
      canvas.drawLine(p, p + Offset(len * dx, 0), handle);
      canvas.drawLine(p, p + Offset(0, len * dy), handle);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    if (showEdgeHandles) {
      const half = 12.0;
      final c = rect.center;
      canvas.drawLine(
        Offset(c.dx - half, rect.top),
        Offset(c.dx + half, rect.top),
        handle,
      );
      canvas.drawLine(
        Offset(c.dx - half, rect.bottom),
        Offset(c.dx + half, rect.bottom),
        handle,
      );
      canvas.drawLine(
        Offset(rect.left, c.dy - half),
        Offset(rect.left, c.dy + half),
        handle,
      );
      canvas.drawLine(
        Offset(rect.right, c.dy - half),
        Offset(rect.right, c.dy + half),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.rect != rect || old.showEdgeHandles != showEdgeHandles;
}
