import 'dart:io';

import 'package:get/get.dart';

import '../models/picked_media.dart';
import '../modules/camera/camera_controller.dart';
import '../modules/camera/camera_view.dart';
import '../modules/crop/crop_controller.dart';
import '../modules/crop/crop_view.dart';
import '../modules/editor/editor_controller.dart';
import '../modules/editor/editor_view.dart';

// The package pushes its screens with `Get.to` + a binding, so the host app
// doesn't have to register any GetPage routes.
//
// Results are read untyped and cast: a typed `Get.toNamed<T>()` on a GetPage
// fails its route cast at runtime, and staying untyped everywhere avoids that
// class of bug.

Future<List<PickedMedia>?> openCameraRoute() async {
  return castMedia(
    await Get.to(
      () => const CameraView(),
      binding: BindingsBuilder(() => Get.lazyPut(CameraScreenController.new)),
      transition: Transition.downToUp,
    ),
  );
}

Future<List<PickedMedia>?> openEditorRoute(List<MediaInput> inputs) async {
  return castMedia(
    await Get.to(
      () => const EditorView(),
      binding: BindingsBuilder(() => Get.lazyPut(EditorController.new)),
      arguments: inputs,
      transition: Transition.fadeIn,
    ),
  );
}

Future<File?> openCropRoute(File file) async {
  final result = await Get.to(
    () => const CropView(),
    binding: BindingsBuilder(() => Get.lazyPut(CropController.new)),
    arguments: file,
    transition: Transition.fadeIn,
  );
  return result is File ? result : null;
}

List<PickedMedia>? castMedia(Object? result) =>
    result is List ? result.whereType<PickedMedia>().toList() : null;

/// Pops the top route (page or bottom sheet) with [result].
///
/// Use this instead of `Get.back(result: ...)`: in GetX 4 that call only
/// dismisses a visible snackbar and returns, silently dropping the result.
void closeWithResult(Object? result) => Get.key.currentState?.pop(result);

/// Pops the top route without a result. Like [closeWithResult], it works
/// while a snackbar is visible (`Get.back()` would only close the snackbar).
void closeRoute() => closeWithResult(null);
