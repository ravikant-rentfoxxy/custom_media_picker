import 'dart:io';
import 'dart:typed_data';

enum MediaKind { image, video }

/// A photo or video handed to the editor (from the camera or the gallery).
class MediaInput {
  const MediaInput({
    required this.file,
    this.kind = MediaKind.image,
    this.thumbnail,
    this.duration = Duration.zero,
  });

  final File file;
  final MediaKind kind;

  /// Poster frame for videos (null for images).
  final Uint8List? thumbnail;
  final Duration duration;

  bool get isVideo => kind == MediaKind.video;
}

/// Final result returned by the picker flow (camera / gallery -> editor).
class PickedMedia {
  const PickedMedia({
    required this.file,
    this.caption = '',
    this.kind = MediaKind.image,
    this.thumbnail,
    this.duration = Duration.zero,
  });

  final File file;
  final String caption;
  final MediaKind kind;
  final Uint8List? thumbnail;
  final Duration duration;

  bool get isVideo => kind == MediaKind.video;
}

/// "m:ss", or "h:mm:ss" for long videos.
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString();
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:${minutes.padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}
