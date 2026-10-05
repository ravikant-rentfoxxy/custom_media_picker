import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/asset_thumbnail.dart';
import '../../routes/media_navigation.dart';
import 'camera_controller.dart';

class CameraView extends GetView<CameraScreenController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Swipe up anywhere to open the full gallery, like WhatsApp.
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -300) controller.openGallery();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Preview(),
            SafeArea(
              child: Column(
                children: [
                  const _TopBar(),
                  const Spacer(),
                  const _RecentStrip(),
                  const SizedBox(height: 20),
                  const _Controls(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Photo',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Obx(
              () => controller.isBusy.value
                  ? const ColoredBox(
                      color: Colors.black38,
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

class _Preview extends GetView<CameraScreenController> {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = controller.error.value;
      final ready = controller.isReady.value;
      final camera = controller.camera;
      if (error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography,
                  color: Colors.white54,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: controller.openSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        );
      }
      if (!ready || camera == null) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      // Scale the preview so it covers the whole screen.
      final size = MediaQuery.sizeOf(context);
      var scale = size.aspectRatio * camera.value.aspectRatio;
      if (scale < 1) scale = 1 / scale;
      return ClipRect(
        child: Transform.scale(
          scale: scale,
          child: Center(child: CameraPreview(camera)),
        ),
      );
    });
  }
}

/// Round translucent icon button used on top of the camera preview.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * .55),
        ),
      ),
    );
  }
}

class _TopBar extends GetView<CameraScreenController> {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _RoundButton(icon: Icons.close, onPressed: closeRoute),
          const Spacer(),
          Obx(
            () => _RoundButton(
              icon: switch (controller.flashMode.value) {
                FlashMode.auto => Icons.flash_auto,
                FlashMode.always => Icons.flash_on,
                _ => Icons.flash_off,
              },
              onPressed: controller.toggleFlash,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentStrip extends GetView<CameraScreenController> {
  const _RecentStrip();

  @override
  Widget build(BuildContext context) {
    // About six thumbnails visible across the screen, like WhatsApp.
    final tile = MediaQuery.sizeOf(context).width / 5.5;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.openGallery,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        SizedBox(
          height: tile,
          child: Obx(
            () => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 2),
              itemBuilder: (_, i) {
                final asset = controller.recent[i];
                return GestureDetector(
                  onTap: () => controller.openRecent(asset),
                  child: SizedBox(
                    width: tile,
                    height: tile,
                    child: AssetThumbnail(asset: asset, size: 200),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends GetView<CameraScreenController> {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(
            icon: Icons.photo_outlined,
            size: 60,
            onPressed: controller.openGallery,
          ),
          GestureDetector(
            onTap: controller.capture,
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.cameraswitch_outlined,
            size: 60,
            onPressed: controller.switchCamera,
          ),
        ],
      ),
    );
  }
}
