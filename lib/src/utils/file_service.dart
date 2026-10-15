import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/picked_media.dart';

/// Picks documents with the system file picker (Storage Access Framework on
/// Android, UIDocumentPicker on iOS). No permission is needed.
abstract final class FileService {
  /// Returns an empty list if the user cancelled. Throws if the picker can't
  /// be opened.
  static Future<List<PickedMedia>> pick({
    required bool multiple,
    List<String>? extensions,
  }) async {
    final custom = extensions != null && extensions.isNotEmpty;
    final type = custom ? FileType.custom : FileType.any;
    final allowed = custom ? extensions : null;
    final files = multiple
        ? await FilePicker.pickFiles(type: type, allowedExtensions: allowed)
        : [?await FilePicker.pickFile(type: type, allowedExtensions: allowed)];
    final media = await Future.wait(files.map(_mediaOf));
    return media.whereType<PickedMedia>().toList();
  }

  static Future<PickedMedia?> _mediaOf(PlatformFile picked) async {
    try {
      var path = picked.path;
      // Not on local disk (e.g. a cloud content URI): copy it to a temp file
      // so callers always get a File.
      if (path == null) {
        final dir = await getTemporaryDirectory();
        final copy = File(
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${picked.name}',
        );
        await copy.writeAsBytes(await picked.readAsBytes());
        path = copy.path;
      }
      return PickedMedia(
        file: File(path),
        kind: MediaKind.file,
        name: picked.name,
        size: picked.lengthSync() ?? await picked.length(),
      );
    } catch (_) {
      return null;
    }
  }
}
