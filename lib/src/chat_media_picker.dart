import 'models/picked_media.dart';
import 'modules/gallery/gallery_sheet.dart';
import 'routes/media_navigation.dart';

/// Options for the picker flow.
class ChatMediaPickerConfig {
  const ChatMediaPickerConfig({this.maxSelection = 10, this.recipientName});

  /// Maximum number of photos/videos selectable in one go.
  final int maxSelection;

  /// Shown as a chip next to the send button in the editor (e.g. the chat
  /// name). Hidden when null.
  final String? recipientName;
}

/// Entry points of the WhatsApp-style attachment picker.
///
/// Requires the app to use `GetMaterialApp`. Every method returns the picked
/// (and edited) media, or null if the user closed the picker.
abstract final class ChatMediaPicker {
  /// Used by the screens of the current flow. Set it once (e.g. in `main`) or
  /// pass `config` to [openGallery] / [openCamera].
  static ChatMediaPickerConfig config = const ChatMediaPickerConfig();

  /// Attach button: gallery bottom sheet with a "Camera" tile, photos and
  /// videos, multi-select, then the editor.
  static Future<List<PickedMedia>?> openGallery({
    ChatMediaPickerConfig? config,
  }) {
    if (config != null) ChatMediaPicker.config = config;
    return openGallerySheet();
  }

  /// Camera button: full-screen camera with a recent-media strip, then the
  /// editor.
  static Future<List<PickedMedia>?> openCamera({
    ChatMediaPickerConfig? config,
  }) {
    if (config != null) ChatMediaPicker.config = config;
    return openCameraRoute();
  }
}
