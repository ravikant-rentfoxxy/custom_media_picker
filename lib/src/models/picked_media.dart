import 'dart:io';
import 'dart:typed_data';

enum MediaKind {
  image,
  video,

  /// Any file picked with the "Document" option (PDF, DOCX, ZIP, ...).
  file,
}

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

/// Final result returned by the picker flow (camera / gallery -> editor, or
/// the file picker).
class PickedMedia {
  const PickedMedia({
    required this.file,
    this.caption = '',
    this.kind = MediaKind.image,
    this.thumbnail,
    this.duration = Duration.zero,
    this.name,
    this.size,
  });

  final File file;
  final String caption;
  final MediaKind kind;
  final Uint8List? thumbnail;
  final Duration duration;

  /// Original file name, set for [MediaKind.file].
  final String? name;

  /// Size in bytes, set for [MediaKind.file].
  final int? size;

  bool get isVideo => kind == MediaKind.video;
  bool get isFile => kind == MediaKind.file;

  /// [name], or the last segment of the file path.
  String get fileName => name ?? file.uri.pathSegments.last;
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

/// "1.2 MB", "640 kB" or "12 B".
String formatFileSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['kB', 'MB', 'GB', 'TB'];
  var size = bytes / 1000;
  var unit = 0;
  while (size >= 1000 && unit < units.length - 1) {
    size /= 1000;
    unit++;
  }
  return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[unit]}';
}
