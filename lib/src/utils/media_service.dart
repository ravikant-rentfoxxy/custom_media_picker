import 'package:photo_manager/photo_manager.dart';

import '../models/picked_media.dart';

/// Thin wrapper around the native photo library (MediaStore / PHPhotoLibrary).
class MediaService {
  MediaService._();

  /// Photos and videos.
  static const _type = RequestType.common;

  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(type: _type, mediaLocation: false),
  );

  static Future<Object?>? _pending;

  /// Android can show only one permission dialog at a time; a second request
  /// while one is open is dropped ("Can request only one set of permissions
  /// at a time") and the user's answer can get lost. Every dialog goes through
  /// here so callers share the request in flight instead of starting another.
  static Future<T> _serialized<T>(Future<T> Function() request) async {
    final pending = _pending;
    if (pending != null) await pending.catchError((_) => null);
    final future = request();
    _pending = future;
    try {
      return await future;
    } finally {
      if (identical(_pending, future)) _pending = null;
    }
  }

  /// True while a system permission dialog / photo picker is open.
  static bool get isRequesting => _pending != null;

  /// Shows the system prompt if needed.
  static Future<PermissionState> requestPermission() {
    return _serialized(
      () => PhotoManager.requestPermissionExtend(
        requestOption: _permissionOption,
      ),
    );
  }

  /// Reads the current state without prompting.
  static Future<PermissionState> permissionState() {
    return PhotoManager.getPermissionState(requestOption: _permissionOption);
  }

  /// "Select more photos": the iOS limited-library picker, or the Android 14+
  /// system photo picker. Photos and videos only (the default also asks for
  /// audio).
  static Future<void> selectMorePhotos() {
    return _serialized(() => PhotoManager.presentLimited(type: _type));
  }

  static Future<List<AssetPathEntity>> albums() {
    return PhotoManager.getAssetPathList(type: _type);
  }

  /// Most recent photos and videos from the "Recents" / "All" album.
  static Future<List<AssetEntity>> recent({int count = 30}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: _type,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    return paths.first.getAssetListPaged(page: 0, size: count);
  }

  /// Resolves gallery assets to files for the editor. Videos also get a
  /// poster frame for the chat bubble. Assets that can't be read are skipped.
  static Future<List<MediaInput>> inputsOf(List<AssetEntity> assets) async {
    final inputs = await Future.wait(assets.map(_inputOf));
    return inputs.whereType<MediaInput>().toList();
  }

  static Future<MediaInput?> _inputOf(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return null;
      if (asset.type != AssetType.video) return MediaInput(file: file);
      return MediaInput(
        file: file,
        kind: MediaKind.video,
        thumbnail: await asset.thumbnailDataWithSize(
          const ThumbnailSize(600, 600),
          quality: 85,
        ),
        duration: asset.videoDuration,
      );
    } catch (_) {
      // e.g. an iCloud item that can't be downloaded right now.
      return null;
    }
  }

  static String albumName(AssetPathEntity path) =>
      path.isAll ? 'Recents' : path.name;

  static Future<void> openSettings() => PhotoManager.openSetting();
}
