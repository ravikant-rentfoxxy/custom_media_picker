import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/picked_media.dart';
import '../../routes/media_navigation.dart';
import '../../utils/app_colors.dart';
import '../../utils/media_service.dart';
import '../../widgets/asset_thumbnail.dart';
import 'gallery_controller.dart';

/// Opens the WhatsApp-style gallery sheet and returns the picked (and edited)
/// media, or null if the user closed it.
///
/// Each sheet gets its own tagged controller, so the sheet can be opened again
/// from the camera screen while the first one is still underneath.
Future<List<PickedMedia>?> openGallerySheet({bool showCamera = true}) async {
  final tag = 'gallery_${DateTime.now().microsecondsSinceEpoch}';
  final controller = Get.put(
    GalleryController(showCamera: showCamera),
    tag: tag,
  );
  try {
    final result = await Get.bottomSheet(
      GallerySheet(controller: controller),
      isScrollControlled: true,
      ignoreSafeArea: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
    return castMedia(result);
  } finally {
    await Get.delete<GalleryController>(tag: tag, force: true);
  }
}

class GallerySheet extends StatelessWidget {
  const GallerySheet({super.key, required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    // Tapping the empty area above the sheet closes it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 1,
        snap: true,
        snapSizes: const [0.8],
        builder: (context, scrollController) => GestureDetector(
          onTap: () {}, // Absorb taps so they don't close the sheet.
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                _Content(controller: controller, scroll: scrollController),
                _SelectionBar(controller: controller),
                Obx(
                  () => controller.isPreparing.value
                      ? const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black26,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.controller, required this.scroll});

  final GalleryController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 800) controller.loadMore();
        return false;
      },
      child: Obx(() {
        final status = controller.status.value;
        final limited = controller.isLimited.value;
        // The header lives inside the scroll view so dragging it also drags
        // the sheet.
        return CustomScrollView(
          controller: scroll,
          slivers: [
            PinnedHeaderSliver(child: _Header(controller: controller)),
            if (status == GalleryStatus.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (status == GalleryStatus.denied)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _PermissionDenied(controller: controller),
              )
            else ...[
              if (limited)
                SliverToBoxAdapter(child: _LimitedBanner(controller)),
              _Grid(controller: controller),
              // Room for the multi-select button and the selection bar.
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Obx(() {
                      if (controller.selectionMode.value) {
                        return Text(
                          '${controller.selected.length} selected',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      final album = controller.currentAlbum.value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showAlbums(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                album == null
                                    ? 'Recents'
                                    : MediaService.albumName(album),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Keeps the title centered (same width as the close button).
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAlbums(BuildContext context) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Obx(
          () => ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: controller.albums.length,
            itemBuilder: (context, i) {
              final album = controller.albums[i];
              return _AlbumTile(
                album: album,
                selected: album == controller.currentAlbum.value,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.selectAlbum(album);
                },
              );
            },
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offset = controller.showCamera ? 1 : 0;
      final count = controller.assets.length + offset;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: count,
          itemBuilder: (_, i) {
            if (i < offset) return _CameraTile(onTap: controller.openCamera);
            final asset = controller.assets[i - offset];
            return _Tile(
              key: ValueKey(asset.id),
              controller: controller,
              asset: asset,
            );
          },
        ),
      );
    });
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F6F6),
      shape: const Border.fromBorderSide(BorderSide(color: Color(0xFFE0E0E0))),
      child: InkWell(
        onTap: onTap,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: AppColors.accent, size: 36),
            SizedBox(height: 6),
            Text('Camera', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.controller, required this.asset});

  final GalleryController controller;
  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.onTap(asset),
      onLongPress: () => controller.onLongPress(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetThumbnail(asset: asset),
          Obx(() {
            final index = controller.selectionIndex(asset);
            final selecting = controller.selectionMode.value;
            if (!selecting && index < 0) return const SizedBox.shrink();
            return Stack(
              fit: StackFit.expand,
              children: [
                if (index >= 0)
                  ColoredBox(color: Colors.white.withValues(alpha: .35)),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index >= 0 ? AppColors.accent : Colors.black26,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: index >= 0
                        ? Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Bottom-right multi-select toggle, and the send bar once photos are picked.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Obx(() {
          final count = controller.selected.length;
          final selecting = controller.selectionMode.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (controller.status.value == GalleryStatus.ready)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    color: selecting ? AppColors.accent : Colors.white,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: controller.toggleSelectionMode,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.filter_none,
                          color: selecting ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              if (count > 0)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count of ${controller.maxSelection} selected',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: null,
                        elevation: 2,
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        onPressed: controller.next,
                        child: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final AssetPathEntity album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 52,
          height: 52,
          child: FutureBuilder<List<AssetEntity>>(
            future: album.getAssetListRange(start: 0, end: 1),
            builder: (_, snap) {
              final cover = snap.data;
              if (cover == null || cover.isEmpty) {
                return const ColoredBox(color: Color(0xFFE0E0E0));
              }
              return AssetThumbnail(asset: cover.first, size: 150);
            },
          ),
        ),
      ),
      title: Text(MediaService.albumName(album)),
      subtitle: FutureBuilder<int>(
        future: album.assetCountAsync,
        builder: (_, snap) => Text(snap.hasData ? '${snap.data} items' : ''),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner(this.controller);

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "You've given access to a selected number of photos.",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: () => _showManageOptions(context),
            child: const Text(
              'Manage',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageOptions(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Builder(
            builder: (sheetContext) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: const Text('Select more photos'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.selectMorePhotos();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Allow access to all photos'),
                  subtitle: const Text(
                    'Opens Settings → Photos and videos → Always allow all',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    // The gallery reloads automatically when the app resumes.
                    controller.openSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Allow access to your photos and videos to share them in the chat.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.init,
            child: const Text('Allow access'),
          ),
          TextButton(
            onPressed: controller.openSettings,
            child: const Text('Open settings'),
          ),
          if (controller.showCamera)
            TextButton.icon(
              onPressed: controller.openCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Use camera instead'),
            ),
        ],
      ),
    );
  }
}
