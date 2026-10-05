import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../chat_media_picker.dart';
import '../../utils/app_colors.dart';
import '../../widgets/color_slider.dart';
import '../../widgets/video_view.dart';
import 'editor_controller.dart';
import 'widgets/edit_canvas.dart';

class EditorView extends GetView<EditorController> {
  const EditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: Stack(
                    children: [
                      Obx(
                        () => PageView.builder(
                          controller: controller.pageController,
                          physics: controller.pagingLocked
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          itemCount: controller.items.length,
                          onPageChanged: controller.onPageChanged,
                          itemBuilder: (_, i) {
                            final item = controller.items[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: item.isVideo
                                  ? Obx(
                                      () => VideoView(
                                        key: ObjectKey(item),
                                        file: item.current.value,
                                        autoPlay: true,
                                        // Pause when swiped away.
                                        active:
                                            controller.currentIndex.value == i,
                                      ),
                                    )
                                  : EditCanvas(
                                      key: ObjectKey(item),
                                      item: item,
                                    ),
                            );
                          },
                        ),
                      ),
                      Obx(
                        () => controller.mode.value == EditMode.draw
                            ? Positioned(
                                top: 8,
                                right: 4,
                                child: ColorSlider(
                                  color: controller.drawColor.value,
                                  onChanged: (c) =>
                                      controller.drawColor.value = c,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => controller.mode.value == EditMode.draw
                      ? const SizedBox(height: 16)
                      : const _BottomBar(),
                ),
              ],
            ),
            Obx(
              () => controller.isBusy.value
                  ? const ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends GetView<EditorController> {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    const iconColor = Colors.white;
    return SizedBox(
      height: 56,
      child: Obx(() {
        final drawing = controller.mode.value == EditMode.draw;
        final hasItems = controller.items.isNotEmpty;
        final canUndo = hasItems && controller.current.undoStack.isNotEmpty;
        // Videos can only be previewed and captioned.
        final canEdit = hasItems && !controller.current.isVideo;
        return Row(
          children: [
            if (drawing)
              TextButton(
                onPressed: controller.toggleDraw,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.close, color: iconColor, size: 28),
                onPressed: Get.back,
              ),
            const Spacer(),
            if (canUndo)
              IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo, color: iconColor),
                onPressed: controller.undo,
              ),
            if (canEdit && !drawing) ...[
              IconButton(
                tooltip: 'Crop & rotate',
                icon: const Icon(Icons.crop_rotate, color: iconColor),
                onPressed: controller.openCrop,
              ),
              IconButton(
                tooltip: 'Text',
                icon: const Icon(Icons.title, color: iconColor),
                onPressed: controller.addText,
              ),
            ],
            if (canEdit)
              IconButton(
                tooltip: 'Draw',
                onPressed: controller.toggleDraw,
                icon: drawing
                    ? CircleAvatar(
                        radius: 15,
                        backgroundColor: controller.drawColor.value,
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: iconColor,
                        ),
                      )
                    : const Icon(Icons.edit, color: iconColor),
              ),
            const SizedBox(width: 4),
          ],
        );
      }),
    );
  }
}

class _BottomBar extends GetView<EditorController> {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Thumbnails(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.editorField,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller.captionController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              if (ChatMediaPicker.config.recipientName case final name?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.editorField,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              const Spacer(),
              FloatingActionButton(
                heroTag: null,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: controller.send,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumbnails extends GetView<EditorController> {
  const _Thumbnails();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.items.toList();
      final selected = controller.currentIndex.value;
      if (items.length < 2) return const SizedBox.shrink();
      return SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final isSelected = i == selected;
            return GestureDetector(
              // Tapping the selected thumbnail removes it, like WhatsApp.
              onTap: () =>
                  isSelected ? controller.removeItem(i) : controller.jumpTo(i),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (items[i].isVideo) ...[
                        if (items[i].input.thumbnail != null)
                          Image.memory(
                            items[i].input.thumbnail!,
                            fit: BoxFit.cover,
                          )
                        else
                          const ColoredBox(color: Colors.white10),
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ] else
                        Obx(
                          () => Image.file(
                            items[i].current.value,
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            gaplessPlayback: true,
                          ),
                        ),
                      if (isSelected)
                        const ColoredBox(
                          color: Colors.black38,
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
