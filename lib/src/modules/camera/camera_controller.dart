import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../routes/media_navigation.dart';
import '../../utils/media_service.dart';
import '../gallery/gallery_sheet.dart';
import '../../models/picked_media.dart';

class CameraScreenController extends GetxController
    with WidgetsBindingObserver {
  CameraController? camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _initializing = false;

  final isReady = false.obs;
  final isBusy = false.obs;
  final error = RxnString();
  final flashMode = FlashMode.off.obs;
  final recent = <AssetEntity>[].obs;

  bool get canSwitch => _cameras.length > 1;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Sequential on purpose: the camera permission dialog must finish before
    // anything else touches permissions.
    _setup().whenComplete(_loadRecent);
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        error.value = 'No camera found on this device';
        return;
      }
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = back == -1 ? 0 : back;
      await _startCamera();
    } on CameraException catch (e) {
      error.value = e.description ?? e.code;
    }
  }

  Future<void> _startCamera() async {
    if (_initializing || _cameras.isEmpty) return;
    _initializing = true;
    isReady.value = false;
    final old = camera;
    camera = null;
    await old?.dispose();

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(flashMode.value).catchError((_) {});
      camera = controller;
      error.value = null;
      isReady.value = true;
    } on CameraException catch (e) {
      await controller.dispose();
      error.value = e.code == 'CameraAccessDenied'
          ? 'Camera permission denied. Enable it from settings.'
          : (e.description ?? e.code);
    } finally {
      _initializing = false;
    }
  }

  /// Recent photos for the strip. Doesn't prompt: photo access is asked for
  /// when the user opens the gallery.
  Future<void> _loadRecent() async {
    final state = await MediaService.permissionState();
    if (!state.hasAccess) return;
    recent.assignAll(await MediaService.recent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = camera;
      camera = null;
      isReady.value = false;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && camera == null) {
      _startCamera();
    }
  }

  Future<void> switchCamera() async {
    if (!canSwitch) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> toggleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(flashMode.value) + 1) % order.length];
    flashMode.value = next;
    await camera?.setFlashMode(next).catchError((_) {});
  }

  Future<void> capture() async {
    final c = camera;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    isBusy.value = true;
    try {
      final shot = await c.takePicture();
      isBusy.value = false;
      await _openEditor([MediaInput(file: File(shot.path))]);
    } on CameraException catch (e) {
      Get.snackbar('Camera', e.description ?? e.code);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> openRecent(AssetEntity asset) async {
    isBusy.value = true;
    final inputs = await MediaService.inputsOf([asset]);
    isBusy.value = false;
    if (inputs.isNotEmpty) await _openEditor(inputs);
  }

  Future<void> openGallery() async {
    await _pausePreview();
    final result = await openGallerySheet(showCamera: false);
    if (result != null && result.isNotEmpty) {
      closeWithResult(result);
    } else {
      await _resumePreview();
      // Photo access may have just been granted in the sheet.
      if (recent.isEmpty) await _loadRecent();
    }
  }

  Future<void> _openEditor(List<MediaInput> inputs) async {
    await _pausePreview();
    final result = await openEditorRoute(inputs);
    if (result != null && result.isNotEmpty) {
      closeWithResult(result);
    } else {
      await _resumePreview();
    }
  }

  Future<void> _pausePreview() async {
    try {
      await camera?.pausePreview();
    } catch (_) {}
  }

  Future<void> _resumePreview() async {
    try {
      await camera?.resumePreview();
    } catch (_) {}
  }

  Future<void> openSettings() => MediaService.openSettings();

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    super.onClose();
  }
}
