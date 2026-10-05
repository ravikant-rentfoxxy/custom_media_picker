import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../chat_media_picker.dart';
import '../../routes/media_navigation.dart';
import '../../utils/media_service.dart';

enum GalleryStatus { loading, denied, ready }

/// Drives the WhatsApp-style gallery bottom sheet.
class GalleryController extends GetxController with WidgetsBindingObserver {
  GalleryController({this.showCamera = true});

  int get maxSelection => ChatMediaPicker.config.maxSelection;
  static const _pageSize = 80;

  /// Show the "Camera" tile as the first grid cell (hidden when the sheet is
  /// opened from the camera screen itself).
  final bool showCamera;

  final status = GalleryStatus.loading.obs;
  final isLimited = false.obs;
  final albums = <AssetPathEntity>[].obs;
  final currentAlbum = Rxn<AssetPathEntity>();
  final assets = <AssetEntity>[].obs;
  final selected = <AssetEntity>[].obs;
  final selectionMode = false.obs;
  final isPreparing = false.obs;

  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// The user may have changed photo access in Settings while away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfAccessChanged();
  }

  /// Only checks the state (never prompts): closing a permission dialog also
  /// resumes the app, and prompting here would show the dialog again.
  Future<void> _refreshIfAccessChanged() async {
    if (status.value == GalleryStatus.loading || MediaService.isRequesting) {
      return;
    }
    final permission = await MediaService.permissionState();
    final nowLimited = permission == PermissionState.limited;
    final wasDenied = status.value == GalleryStatus.denied;
    if (permission.hasAccess == wasDenied || nowLimited != isLimited.value) {
      await reload();
    }
  }

  /// Reloads albums and photos without prompting, keeping the current album
  /// if it still exists.
  Future<void> reload() async {
    final albumId = currentAlbum.value?.id;
    await init(prompt: false);
    final same = albums.firstWhereOrNull((a) => a.id == albumId);
    if (same != null && same != currentAlbum.value) await selectAlbum(same);
  }

  /// Loads the gallery. With [prompt] the system permission dialog is shown
  /// when access hasn't been granted yet.
  Future<void> init({bool prompt = true}) async {
    status.value = GalleryStatus.loading;
    final permission = prompt
        ? await MediaService.requestPermission()
        : await MediaService.permissionState();
    if (!permission.hasAccess) {
      status.value = GalleryStatus.denied;
      return;
    }
    isLimited.value = permission == PermissionState.limited;
    albums.assignAll(await MediaService.albums());
    if (albums.isNotEmpty) {
      await selectAlbum(albums.first);
    }
    status.value = GalleryStatus.ready;
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    currentAlbum.value = album;
    assets.clear();
    _page = 0;
    _hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    final album = currentAlbum.value;
    if (album == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final list = await album.getAssetListPaged(page: _page, size: _pageSize);
      // Ignore results if the user switched album meanwhile.
      if (album == currentAlbum.value) {
        assets.addAll(list);
        _page++;
        _hasMore = list.length == _pageSize;
      }
    } catch (_) {
      // Leave _hasMore as is: the next scroll retries.
    } finally {
      _loadingMore = false;
    }
  }

  int selectionIndex(AssetEntity asset) =>
      selected.indexWhere((a) => a.id == asset.id);

  void toggle(AssetEntity asset) {
    final index = selectionIndex(asset);
    if (index >= 0) {
      selected.removeAt(index);
      if (selected.isEmpty) selectionMode.value = false;
    } else if (selected.length >= maxSelection) {
      Get.rawSnackbar(
        message: 'You can only share up to $maxSelection photos',
        duration: const Duration(seconds: 2),
      );
    } else {
      selected.add(asset);
    }
  }

  void toggleSelectionMode() {
    selectionMode.toggle();
    if (!selectionMode.value) selected.clear();
  }

  void onTap(AssetEntity asset) {
    if (selectionMode.value) {
      toggle(asset);
    } else {
      _openEditor([asset]);
    }
  }

  void onLongPress(AssetEntity asset) {
    selectionMode.value = true;
    toggle(asset);
  }

  void next() {
    if (selected.isNotEmpty) _openEditor(selected.toList());
  }

  Future<void> openCamera() async {
    final result = await openCameraRoute();
    if (result != null && result.isNotEmpty) closeWithResult(result);
  }

  Future<void> _openEditor(List<AssetEntity> picked) async {
    if (isPreparing.value) return;
    isPreparing.value = true;
    final inputs = await MediaService.inputsOf(picked);
    isPreparing.value = false;
    if (inputs.isEmpty) {
      Get.rawSnackbar(message: 'Could not load the selected media');
      return;
    }
    final result = await openEditorRoute(inputs);
    if (result != null && result.isNotEmpty) closeWithResult(result);
  }

  /// "Select more photos" from the limited-access banner.
  Future<void> selectMorePhotos() async {
    await MediaService.selectMorePhotos();
    // Drop selections of photos that may no longer be accessible.
    selected.clear();
    selectionMode.value = false;
    await reload();
  }

  Future<void> openSettings() => MediaService.openSettings();
}
