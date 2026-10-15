# chat_media_picker

Chat attachment picker for Flutter apps using **GetX**.

- **Attachment sheet**: Gallery, Camera and Document options sit over your recent photos. Drag it up and the options crossfade into the full gallery (album switcher, photos and videos, numbered multi-select) while the chat behind dims.
- **File picker**: the Document option picks any file (or only the extensions you allow) with the system picker.
- **Configurable**: turn Gallery, Camera and Document on or off, and theme every colour of the sheet (light and dark presets included).
- **Camera**: full-screen preview, flash, front/back switch, recent-media strip, swipe up for the gallery.
- **Editor**: swipe between picked items, caption per item, crop (free or fixed ratios), rotate, flip, draw, text, undo. Videos are previewed and captioned.

It doesn't use `image_picker` or `image_cropper`. The photo library is read with `photo_manager`, the preview uses `camera`, documents use `file_picker`, and editing is done with `dart:ui`.

| Attach panel | Gallery | Editor | Dark theme |
| :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/1_attach_panel.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/2_gallery_multi_select.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/3_editor.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/6_dark_gallery.jpg" width="200"> |

## Install

```sh
flutter pub add chat_media_picker get
```

Requires Flutter 3.38 or later. Android and iOS (14.0+, required by `file_picker`) are supported.

The app must use **`GetMaterialApp`**, because the picker navigates with GetX.

## Usage

```dart
import 'package:chat_media_picker/chat_media_picker.dart';

// Optional, once at startup.
ChatMediaPicker.config = const ChatMediaPickerConfig(
  maxSelection: 10,
  recipientName: 'Sample Chat', // chip next to the send button; null hides it
  enableGallery: true,     // "Gallery" option + photo grid
  enableCamera: true,      // "Camera" option
  enableFilePicker: true,  // "Document" option
  allowMultipleFiles: true,
  allowedFileExtensions: null, // e.g. ['pdf', 'docx']; null = any file
  theme: ChatMediaPickerTheme(), // or ChatMediaPickerTheme.dark()
);

// Attach button → attachment sheet.
final media = await ChatMediaPicker.openGallery();

// Camera button → camera screen.
final shots = await ChatMediaPicker.openCamera();

for (final m in media ?? <PickedMedia>[]) {
  m.file;       // File (edited photos are PNGs in the temp directory)
  m.caption;    // String
  m.isVideo;    // bool
  m.thumbnail;  // Uint8List? poster frame (videos)
  m.duration;   // Duration (videos)
  m.isFile;     // bool: picked with "Document" (no editor, no caption)
  m.fileName;   // original name (files)
  m.size;       // int? bytes (files), see formatFileSize
}
```

Both methods return `null` when the user closes the picker. `openGallery` also returns `null` right away if all three options are disabled.

### Options

| Flag | Off means |
| --- | --- |
| `enableGallery` | No Gallery option and no photo grid: the sheet is a compact options panel. Photo access is never asked for, and the camera screen hides its recent strip and gallery button. |
| `enableCamera` | No Camera option. `openCamera()` still works if you call it yourself. |
| `enableFilePicker` | No Document option. |

### Theme

Every colour of the sheet comes from `ChatMediaPickerTheme`: background, handle, text, icons, accent (selection badges, send button), option chips and their icon colours, scrim, placeholders, banner, and corner radius.

```dart
ChatMediaPickerConfig(
  theme: const ChatMediaPickerTheme.dark().copyWith(
    accentColor: Colors.deepPurple,
    onAccentColor: Colors.white,
  ),
)
```

The accent colour is also used for the editor's send button. The package also exports `VideoView`, a simple player for showing a sent video, and `formatDuration`.

## Platform setup

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### iOS

Set the deployment target to 14.0 or later (`platform :ios, '14.0'` in `ios/Podfile`), then add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to take photos to share in the chat.</string>
<key>NSMicrophoneUsageDescription</key>
<string>The microphone is required by the camera plugin.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Your photo library is used to pick photos and videos to share.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

## Notes

- The collapsed panel leaves the chat undimmed and the scrim fades in as the sheet expands. The sheet is a modal route, so it covers your chat's input bar rather than pushing it up.

- With "limited" photo access (Android 14+ / iOS), the sheet shows a banner. **Manage** lets the user select more items or open Settings, and the sheet reloads when they come back.
- Android shows the system photo picker when the user chooses "Allow limited access". That screen belongs to the OS and can't be customised.
- Camera recording (video) isn't supported yet; the camera takes photos only.
