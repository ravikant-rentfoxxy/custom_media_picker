# chat_media_picker

WhatsApp-style attachment picker for Flutter apps using **GetX**.

- **Gallery bottom sheet**: draggable, album switcher, "Camera" tile, photos and videos, numbered multi-select.
- **Camera**: full-screen preview, flash, front/back switch, recent-media strip, swipe up for the gallery.
- **Editor**: swipe between picked items, caption per item, crop (free or fixed ratios), rotate, flip, draw, text, undo. Videos are previewed and captioned.

It doesn't use `image_picker` or `image_cropper`. The photo library is read with `photo_manager`, the preview uses `camera`, and editing is done with `dart:ui`.

## Install

```sh
flutter pub add chat_media_picker get
```

Requires Flutter 3.38 or later. Android and iOS are supported.

The app must use **`GetMaterialApp`**, because the picker navigates with GetX.

## Usage

```dart
import 'package:chat_media_picker/chat_media_picker.dart';

// Optional, once at startup.
ChatMediaPicker.config = const ChatMediaPickerConfig(
  maxSelection: 10,
  recipientName: 'Sample Chat', // chip next to the send button; null hides it
);

// Attach button → gallery sheet.
final media = await ChatMediaPicker.openGallery();

// Camera button → camera screen.
final shots = await ChatMediaPicker.openCamera();

for (final m in media ?? <PickedMedia>[]) {
  m.file;       // File (edited photos are PNGs in the temp directory)
  m.caption;    // String
  m.isVideo;    // bool
  m.thumbnail;  // Uint8List? poster frame (videos)
  m.duration;   // Duration (videos)
}
```

Both methods return `null` when the user closes the picker. The package also exports `VideoView`, a simple player for showing a sent video, and `formatDuration`.

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

### iOS (`ios/Runner/Info.plist`)

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

- With "limited" photo access (Android 14+ / iOS), the sheet shows a banner. **Manage** lets the user select more items or open Settings, and the sheet reloads when they come back.
- Android shows the system photo picker when the user chooses "Allow limited access". That screen belongs to the OS and can't be customised.
- Camera recording (video) isn't supported yet; the camera takes photos only.
