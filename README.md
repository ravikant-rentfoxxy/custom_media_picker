# chat_media_picker

Chat attachment picker for Flutter (GetX): a draggable sheet with gallery, camera and file options, plus a photo editor (crop, rotate, draw, text, captions).

| Attach panel | Gallery | Editor | Dark theme |
| :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/1_attach_panel.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/2_gallery_multi_select.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/3_editor.jpg" width="200"> | <img src="https://raw.githubusercontent.com/ravikant-rentfoxxy/custom_media_picker/main/screenshots/6_dark_gallery.jpg" width="200"> |

## Install

```sh
flutter pub add chat_media_picker get
```

Android, and iOS 14.0+. The app must use `GetMaterialApp`.

## Usage

```dart
final media = await ChatMediaPicker.openGallery(); // attachment sheet
final shots = await ChatMediaPicker.openCamera();  // camera screen

for (final m in media ?? <PickedMedia>[]) {
  m.file; m.caption; m.isVideo; m.isFile; m.fileName;
}
```

Both return `null` when the user closes the picker.

## Options

```dart
ChatMediaPicker.config = const ChatMediaPickerConfig(
  maxSelection: 10,
  enableGallery: true,
  enableCamera: true,
  enableFilePicker: true,
  allowedFileExtensions: null, // e.g. ['pdf']
  showCloseButton: true,
  theme: ChatMediaPickerTheme(), // or ChatMediaPickerTheme.dark()
);
```

Use `ChatMediaPickerTheme().copyWith(...)` to change individual colours.

## Platform setup

**Android** (`AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

**iOS** (`platform :ios, '14.0'` in the Podfile, and `Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos to share in the chat.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Required by the camera plugin.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick photos and videos to share.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```
