## 0.2.1

* Shorter package description.

## 0.2.0

* New attachment sheet. Gallery, Camera and Document options sit over the
  recent photos. Dragging up crossfades the options into the "Recents"
  header, expands to the full gallery and dims the screen behind it.
* Camera tile as the first cell of the photo grid.
* File picker ("Document" option). Files come back as `PickedMedia` with
  `MediaKind.file`, `name` and `size`. New `formatFileSize` helper.
* `ChatMediaPickerConfig.enableGallery`, `enableCamera`, `enableFilePicker`,
  `allowMultipleFiles`, `allowedFileExtensions` and `showCloseButton` (a close
  button beside the drag handle, on by default).
* Camera tile as the first cell of the photo grid.
* Crop ratio options no longer pick up the host app's chip theme (they could
  turn unreadable).
* Video badge no longer overflows on small thumbnails (album covers).
* `ChatMediaPickerTheme` (light default and `.dark()`), set through
  `ChatMediaPickerConfig.theme`.
* Screenshots on pub.dev, captured by `example/integration_test/screenshots_test.dart`.
* The example app now includes its `android` and `ios` folders.
* **Breaking:** iOS 14.0 is now the minimum (required by `file_picker`).
* **Breaking:** `MediaKind` has a new `file` value, so exhaustive `switch`es
  over it need a new case.

## 0.1.0

* Initial release:
  gallery bottom sheet (photos + videos), custom camera, editor with crop,
  rotate, flip, draw, text and captions.
