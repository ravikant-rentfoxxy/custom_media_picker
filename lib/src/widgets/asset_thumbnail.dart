import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/picked_media.dart';

/// Loads and caches a gallery thumbnail directly from the native library.
/// Videos get a WhatsApp-style camera icon + duration badge.
class AssetThumbnail extends StatefulWidget {
  const AssetThumbnail({super.key, required this.asset, this.size = 250});

  final AssetEntity asset;
  final int size;

  @override
  State<AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<AssetThumbnail> {
  // Map literals are insertion-ordered, so the first key is the oldest.
  static final _cache = <String, Uint8List>{};
  static const _maxCache = 400;

  Uint8List? _bytes;

  String get _key => '${widget.asset.id}_${widget.size}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.size != widget.size) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final key = _key;
    final cached = _cache[key];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    final bytes = await widget.asset.thumbnailDataWithSize(
      ThumbnailSize.square(widget.size),
      quality: 80,
    );
    if (bytes == null) return;
    _cache[key] = bytes;
    if (_cache.length > _maxCache) _cache.remove(_cache.keys.first);
    if (mounted && key == _key) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final image = bytes == null
        ? const ColoredBox(color: Color(0xFF2A2A2A))
        : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    if (widget.asset.type != AssetType.video) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 10, 5, 3),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const Spacer(),
                Text(
                  formatDuration(widget.asset.videoDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
