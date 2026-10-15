import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../chat_media_picker.dart';
import '../../models/picked_media.dart';
import '../../routes/media_navigation.dart';
import '../../theme/chat_media_picker_theme.dart';
import '../../utils/media_service.dart';
import '../../widgets/asset_thumbnail.dart';
import 'gallery_controller.dart';

/// Opens the attachment sheet and returns the picked (and
/// edited) media, or null if the user closed it.
///
/// Collapsed, the sheet is an options panel (Gallery, Camera, Document) over
/// the most recent photos. Dragging it up expands it into the full gallery:
/// the options fade out while the "Recents" header fades in, and the screen
/// behind dims. [fromCamera] opens the gallery expanded, without options.
///
/// Each sheet gets its own tagged controller, so the sheet can be opened again
/// from the camera screen while the first one is still underneath.
Future<List<PickedMedia>?> openGallerySheet({bool fromCamera = false}) async {
  final config = ChatMediaPicker.config;
  if (!fromCamera &&
      !config.enableGallery &&
      !config.enableCamera &&
      !config.enableFilePicker) {
    return null;
  }
  final tag = 'gallery_${DateTime.now().microsecondsSinceEpoch}';
  final controller = Get.put(
    GalleryController(fromCamera: fromCamera),
    tag: tag,
  );
  final draggable = controller.showGallery;
  try {
    final result = await Get.bottomSheet(
      GallerySheet(controller: controller),
      isScrollControlled: true,
      // The sheet handles the safe area itself: expanded, it stops under the
      // host's app bar.
      ignoreSafeArea: true,
      // The gallery sheet fills the route and handles drags and outside taps
      // itself; the options-only panel uses the route's.
      enableDrag: !draggable,
      backgroundColor: Colors.transparent,
      // The chat stays undimmed behind the collapsed panel; the gallery sheet
      // fades its own scrim in as it expands.
      barrierColor: Colors.transparent,
      elevation: 0,
      enterBottomSheetDuration: const Duration(milliseconds: 200),
      exitBottomSheetDuration: const Duration(milliseconds: 200),
    );
    return castMedia(result);
  } finally {
    await Get.delete<GalleryController>(tag: tag, force: true);
  }
}

const _handleHeight = 18.0;

/// Handle row with the close button beside the handle.
const _closeRowHeight = 44.0;
const _titleBarHeight = 52.0;

class GallerySheet extends StatefulWidget {
  const GallerySheet({super.key, required this.controller});

  final GalleryController controller;

  @override
  State<GallerySheet> createState() => _GallerySheetState();
}

class _GallerySheetState extends State<GallerySheet> {
  final _sheet = DraggableScrollableController();

  /// 0 = collapsed options panel, 1 = expanded gallery.
  late final _progress = ValueNotifier<double>(_hasOptions ? 0 : 1);

  /// Sheet sizes as fractions of the screen height, set by [build].
  double _collapsed = 1;
  double _expanded = 1;
  bool _closing = false;

  GalleryController get controller => widget.controller;
  bool get _hasOptions => !controller.fromCamera;

  /// The close button beside the handle. Opened from the camera, the gallery
  /// title bar (with its own close button) is always shown instead.
  bool get _showClose => ChatMediaPicker.config.showCloseButton && _hasOptions;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    _sheet.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onSheetChanged() {
    final size = _sheet.size;
    _progress.value = _progressAt(size);
    // Dragged below the collapsed panel: the sheet snapped shut.
    if (size < 0.01) _close();
  }

  double _progressAt(double size) {
    if (_expanded <= _collapsed) return 1;
    return ((size - _collapsed) / (_expanded - _collapsed)).clamp(0.0, 1.0);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    // May be called from a drag or snap callback: pop after the frame. By then
    // the sheet may already be closing (e.g. the system back gesture), and
    // popping again would close the host's screen instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
    });
  }

  void _expand() {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      _expanded,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  List<_AttachOption> _options(ChatMediaPickerTheme theme) => [
    if (controller.showGallery && _hasOptions)
      _AttachOption(
        icon: Icons.photo_library_rounded,
        label: 'Gallery',
        color: theme.galleryIconColor,
        onTap: _expand,
      ),
    if (controller.showCamera)
      _AttachOption(
        icon: Icons.camera_alt_rounded,
        label: 'Camera',
        color: theme.cameraIconColor,
        onTap: controller.openCamera,
      ),
    if (controller.showFiles)
      _AttachOption(
        icon: Icons.insert_drive_file_rounded,
        label: 'Document',
        color: theme.documentIconColor,
        onTap: controller.pickFiles,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ChatMediaPicker.config.theme;
    final options = _options(theme);
    if (!controller.showGallery) {
      return _OptionsPanel(
        controller: controller,
        options: options,
        theme: theme,
        showClose: ChatMediaPicker.config.showCloseButton,
      );
    }

    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    // Expanded, the sheet stops under the host's app bar.
    _expanded = ((screen.height - padding.top - kToolbarHeight) / screen.height)
        .clamp(0.5, 1.0);
    // Collapsed: handle, options and about a row and a third of photos.
    final collapsedHeight =
        (_showClose ? _closeRowHeight : _handleHeight) +
        _OptionsGrid.heightFor(options.length) +
        screen.width / 4 * 1.35 +
        padding.bottom;
    _collapsed = _hasOptions
        ? math.min(collapsedHeight / screen.height, _expanded)
        : _expanded;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tapping above the sheet closes it.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, t, _) => ColoredBox(
                color: theme.scrimColor.withValues(
                  alpha: theme.scrimColor.a * t,
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: _collapsed,
            minChildSize: 0,
            maxChildSize: _expanded,
            // [_close] pops the sheet; the route's BottomSheet must not pop it
            // as well when the extent reaches 0.
            shouldCloseOnMinExtent: false,
            snap: true,
            snapSizes: [if (_collapsed < _expanded) _collapsed],
            snapAnimationDuration: const Duration(milliseconds: 250),
            builder: (context, scrollController) => GestureDetector(
              onTap: () {}, // Absorb taps so they don't close the sheet.
              child: Material(
                color: theme.backgroundColor,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.borderRadius),
                ),
                child: Stack(
                  children: [
                    _Content(
                      controller: controller,
                      scroll: scrollController,
                      progress: _progress,
                      options: options,
                      theme: theme,
                      onClose: _showClose ? _close : null,
                    ),
                    _SelectionBar(
                      controller: controller,
                      progress: _progress,
                      theme: theme,
                    ),
                    _PreparingOverlay(controller: controller, theme: theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery disabled: just the options, sized to fit.
class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    required this.controller,
    required this.options,
    required this.theme,
    required this.showClose,
  });

  final GalleryController controller;
  final List<_AttachOption> options;
  final ChatMediaPickerTheme theme;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.backgroundColor,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(theme.borderRadius),
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Handle(
                  theme: theme,
                  onClose: showClose ? () => Navigator.of(context).pop() : null,
                ),
                _OptionsGrid(options: options, theme: theme),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _PreparingOverlay(controller: controller, theme: theme),
        ],
      ),
    );
  }
}

class _PreparingOverlay extends StatelessWidget {
  const _PreparingOverlay({required this.controller, required this.theme});

  final GalleryController controller;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.isPreparing.value
          ? Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.controller,
    required this.scroll,
    required this.progress,
    required this.options,
    required this.theme,
    required this.onClose,
  });

  final GalleryController controller;
  final ScrollController scroll;
  final ValueListenable<double> progress;
  final List<_AttachOption> options;
  final ChatMediaPickerTheme theme;
  final VoidCallback? onClose;

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
            PinnedHeaderSliver(
              child: _Header(
                controller: controller,
                progress: progress,
                options: options,
                theme: theme,
                onClose: onClose,
              ),
            ),
            if (status == GalleryStatus.loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  ),
                ),
              )
            else if (status == GalleryStatus.denied)
              SliverToBoxAdapter(
                child: _PermissionDenied(controller: controller, theme: theme),
              )
            else ...[
              if (limited)
                SliverToBoxAdapter(
                  child: _LimitedBanner(controller: controller, theme: theme),
                ),
              _Grid(controller: controller, theme: theme),
              // Room for the multi-select button and the selection bar.
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ],
        );
      }),
    );
  }
}

/// Drag handle, with a close button on the right when [onClose] is set. With
/// [progress], the close button fades out as the sheet expands (the gallery
/// title bar has its own).
class _Handle extends StatelessWidget {
  const _Handle({required this.theme, this.onClose, this.progress});

  final ChatMediaPickerTheme theme;
  final VoidCallback? onClose;
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    final handle = Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.handleColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    final onClose = this.onClose;
    if (onClose == null) {
      return SizedBox(height: _handleHeight, child: handle);
    }
    final close = IconButton(
      tooltip: 'Close',
      icon: Icon(Icons.close, color: theme.iconColor, size: 24),
      onPressed: onClose,
    );
    Widget row(double t) {
      final opacity = (1 - t / .6).clamp(0.0, 1.0);
      return SizedBox(
        // Shrinks back to the plain handle as the gallery expands.
        height: lerpDouble(_closeRowHeight, _handleHeight, t),
        child: Stack(
          children: [
            handle,
            if (opacity > 0)
              Positioned(
                top: 0,
                right: 4,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: t > .5,
                  child: Opacity(
                    opacity: opacity,
                    child: ClipRect(child: close),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final progress = this.progress;
    if (progress == null) return row(0);
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (_, t, _) => row(t),
    );
  }
}

/// Handle, then the options panel crossfading into the "Recents" title bar as
/// the sheet expands. The options stay pinned to the top and get clipped as
/// the area shrinks to the title bar's height; the title bar sits at its
/// bottom.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.progress,
    required this.options,
    required this.theme,
    required this.onClose,
  });

  final GalleryController controller;
  final ValueListenable<double> progress;
  final List<_AttachOption> options;
  final ChatMediaPickerTheme theme;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final optionsHeight = _OptionsGrid.heightFor(options.length);
    final grid = _OptionsGrid(options: options, theme: theme);
    final titleBar = _TitleBar(controller: controller, theme: theme);
    return ColoredBox(
      color: theme.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(theme: theme, onClose: onClose, progress: progress),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, t, _) {
              final height = options.isEmpty
                  ? _titleBarHeight
                  : lerpDouble(optionsHeight, _titleBarHeight, t)!;
              // Options are gone by 60%; the title starts at 20%.
              final optionsOpacity = (1 - t / .6).clamp(0.0, 1.0);
              final titleOpacity = options.isEmpty
                  ? 1.0
                  : ((t - .2) / .6).clamp(0.0, 1.0);
              return SizedBox(
                height: height,
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (optionsOpacity > 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: optionsHeight,
                          child: IgnorePointer(
                            ignoring: t > .5,
                            child: Opacity(
                              opacity: optionsOpacity,
                              child: grid,
                            ),
                          ),
                        ),
                      if (titleOpacity > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: _titleBarHeight,
                          child: IgnorePointer(
                            ignoring: t < .5,
                            child: Opacity(
                              opacity: titleOpacity,
                              child: titleBar,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttachOption {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Attach options: four per row, a tinted icon in a rounded chip
/// with the label underneath.
class _OptionsGrid extends StatelessWidget {
  const _OptionsGrid({required this.options, required this.theme});

  final List<_AttachOption> options;
  final ChatMediaPickerTheme theme;

  static const _columns = 4;
  static const _rowHeight = 70.0;
  static const _verticalPadding = 6.0;

  static double heightFor(int count) => count == 0
      ? 0
      : (count / _columns).ceil() * _rowHeight + _verticalPadding * 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: _verticalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth / _columns;
          return Wrap(
            children: [
              for (final option in options)
                SizedBox(
                  width: width,
                  height: _rowHeight,
                  child: _OptionButton(option: option, theme: theme),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.option, required this.theme});

  final _AttachOption option;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 36,
            decoration: ShapeDecoration(
              color: theme.optionBackgroundColor,
              shape: const StadiumBorder(),
            ),
            child: Icon(option.icon, color: option.color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.controller, required this.theme});

  final GalleryController controller;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: theme.textColor,
    );
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.close, size: 28, color: theme.iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: Obx(() {
              if (controller.selectionMode.value) {
                return Text(
                  '${controller.selected.length} selected',
                  style: titleStyle,
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
                        style: titleStyle,
                      ),
                      Icon(Icons.arrow_drop_down, color: theme.iconColor),
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
    );
  }

  void _showAlbums(BuildContext context) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                theme: theme,
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
  const _Grid({required this.controller, required this.theme});

  final GalleryController controller;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // The Camera tile is the first cell.
      final offset = controller.showCamera ? 1 : 0;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: controller.assets.length + offset,
          itemBuilder: (_, i) {
            if (i < offset) {
              return _CameraTile(onTap: controller.openCamera, theme: theme);
            }
            final asset = controller.assets[i - offset];
            return _Tile(
              key: ValueKey(asset.id),
              controller: controller,
              asset: asset,
              theme: theme,
            );
          },
        ),
      );
    });
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.onTap, required this.theme});

  final VoidCallback onTap;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.optionBackgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_rounded,
              color: theme.cameraIconColor,
              size: 34,
            ),
            const SizedBox(height: 6),
            Text(
              'Camera',
              style: TextStyle(fontSize: 14, color: theme.secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.controller,
    required this.asset,
    required this.theme,
  });

  final GalleryController controller;
  final AssetEntity asset;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.onTap(asset),
      onLongPress: () => controller.onLongPress(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetThumbnail(
            asset: asset,
            placeholderColor: theme.placeholderColor,
          ),
          Obx(() {
            final index = controller.selectionIndex(asset);
            final selecting = controller.selectionMode.value;
            if (!selecting && index < 0) return const SizedBox.shrink();
            return Stack(
              fit: StackFit.expand,
              children: [
                if (index >= 0) ColoredBox(color: theme.selectedOverlayColor),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index >= 0 ? theme.accentColor : Colors.black26,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: index >= 0
                        ? Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.onAccentColor,
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

/// Bottom-right multi-select toggle (fades in as the sheet expands), and the
/// send bar once photos are picked.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.controller,
    required this.progress,
    required this.theme,
  });

  final GalleryController controller;
  final ValueListenable<double> progress;
  final ChatMediaPickerTheme theme;

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
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, t, child) => IgnorePointer(
                    ignoring: t < .5 && !selecting,
                    child: Opacity(opacity: selecting ? 1 : t, child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      color: selecting
                          ? theme.accentColor
                          : theme.backgroundColor,
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
                            color: selecting
                                ? theme.onAccentColor
                                : theme.iconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (count > 0)
                Container(
                  color: theme.backgroundColor,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count of ${controller.maxSelection} selected',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: null,
                        elevation: 2,
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.onAccentColor,
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
    required this.theme,
    required this.onTap,
  });

  final AssetPathEntity album;
  final bool selected;
  final ChatMediaPickerTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      textColor: theme.textColor,
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
                return ColoredBox(color: theme.placeholderColor);
              }
              return AssetThumbnail(
                asset: cover.first,
                size: 150,
                placeholderColor: theme.placeholderColor,
              );
            },
          ),
        ),
      ),
      title: Text(MediaService.albumName(album)),
      subtitle: FutureBuilder<int>(
        future: album.assetCountAsync,
        builder: (_, snap) => Text(
          snap.hasData ? '${snap.data} items' : '',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      ),
      trailing: selected ? Icon(Icons.check, color: theme.primaryColor) : null,
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.controller, required this.theme});

  final GalleryController controller;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.bannerColor,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "You've given access to a selected number of photos.",
              style: TextStyle(fontSize: 13, color: theme.textColor),
            ),
          ),
          TextButton(
            onPressed: () => _showManageOptions(context),
            child: Text('Manage', style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showManageOptions(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Builder(
            builder: (sheetContext) => ListTileTheme(
              textColor: theme.textColor,
              iconColor: theme.iconColor,
              child: Column(
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
                    subtitle: Text(
                      'Opens Settings → Photos and videos → Always allow all',
                      style: TextStyle(color: theme.secondaryTextColor),
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
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.controller, required this.theme});

  final GalleryController controller;
  final ChatMediaPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    final textButtonStyle = TextButton.styleFrom(
      foregroundColor: theme.primaryColor,
    );
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Allow access to your photos and videos to share them in the chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.backgroundColor,
            ),
            onPressed: controller.init,
            child: const Text('Allow access'),
          ),
          TextButton(
            style: textButtonStyle,
            onPressed: controller.openSettings,
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }
}
