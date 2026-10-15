import 'models/picked_media.dart';
import 'modules/gallery/gallery_sheet.dart';
import 'routes/media_navigation.dart';
import 'theme/chat_media_picker_theme.dart';

/// Options for the picker flow.
class ChatMediaPickerConfig {
  const ChatMediaPickerConfig({
    this.maxSelection = 10,
    this.recipientName,
    this.enableGallery = true,
    this.enableCamera = true,
    this.enableFilePicker = true,
    this.allowMultipleFiles = true,
    this.allowedFileExtensions,
    this.showCloseButton = true,
    this.theme = const ChatMediaPickerTheme(),
  });

  /// Maximum number of photos/videos (or files) selectable in one go.
  final int maxSelection;

  /// Shown as a chip next to the send button in the editor (e.g. the chat
  /// name). Hidden when null.
  final String? recipientName;

  /// "Gallery" option and the photo grid of the attachment sheet. When false
  /// the sheet is a compact options panel and photo access is never asked
  /// for.
  final bool enableGallery;

  /// "Camera" option of the attachment sheet.
  final bool enableCamera;

  /// "Document" option of the attachment sheet: picks any file with the
  /// system file picker. Files are returned as is (no editor), with
  /// [MediaKind.file].
  final bool enableFilePicker;

  /// Let the user pick several files at once (up to [maxSelection]).
  final bool allowMultipleFiles;

  /// Restricts the file picker to these extensions, without the dot (e.g.
  /// `['pdf', 'docx']`). Null allows any file.
  final List<String>? allowedFileExtensions;

  /// Close button at the top right of the attachment sheet, beside the drag
  /// handle. It fades out as the gallery expands, whose title bar has its own.
  final bool showCloseButton;

  /// Colours of the attachment sheet.
  final ChatMediaPickerTheme theme;
}

/// Entry points of the chat attachment picker.
///
/// Requires the app to use `GetMaterialApp`. Every method returns the picked
/// (and edited) media, or null if the user closed the picker.
abstract final class ChatMediaPicker {
  /// Used by the screens of the current flow. Set it once (e.g. in `main`) or
  /// pass `config` to [openGallery] / [openCamera].
  static ChatMediaPickerConfig config = const ChatMediaPickerConfig();

  /// Attach button: options panel (Gallery, Camera, Document) over a strip of
  /// recent photos. Dragging it up expands it into the full gallery with
  /// multi-select; picked photos then go through the editor.
  ///
  /// Returns null right away if every option is disabled.
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
