import 'package:flutter/material.dart';

/// Colours of the attachment sheet (options panel, gallery, album list).
///
/// The defaults are a neutral light theme with an indigo accent. Use
/// [ChatMediaPickerTheme.dark] for a dark sheet, or [copyWith] to change a few colours:
///
/// ```dart
/// ChatMediaPickerConfig(
///   theme: const ChatMediaPickerTheme().copyWith(accentColor: Colors.indigo),
/// )
/// ```
@immutable
class ChatMediaPickerTheme {
  const ChatMediaPickerTheme({
    this.backgroundColor = Colors.white,
    this.handleColor = const Color(0x42000000),
    this.textColor = const Color(0xDD000000),
    this.secondaryTextColor = const Color(0x8A000000),
    this.iconColor = const Color(0xDD000000),
    this.accentColor = const Color(0xFF4F46E5),
    this.onAccentColor = Colors.white,
    this.primaryColor = const Color(0xFF4F46E5),
    this.optionBackgroundColor = const Color(0xFFF1F2F6),
    this.galleryIconColor = const Color(0xFF2563EB),
    this.cameraIconColor = const Color(0xFFDB2777),
    this.documentIconColor = const Color(0xFF7C3AED),
    this.scrimColor = const Color(0x66000000),
    this.placeholderColor = const Color(0xFFE0E0E0),
    this.bannerColor = const Color(0xFFF0F2F5),
    this.selectedOverlayColor = const Color(0x59FFFFFF),
    this.borderRadius = 24,
  });

  /// Dark sheet with the same accent family.
  const ChatMediaPickerTheme.dark({
    this.backgroundColor = const Color(0xFF1C1C21),
    this.handleColor = const Color(0x4DFFFFFF),
    this.textColor = const Color(0xFFF2F2F5),
    this.secondaryTextColor = const Color(0xFF9A9AA5),
    this.iconColor = const Color(0xFFF2F2F5),
    this.accentColor = const Color(0xFF818CF8),
    this.onAccentColor = const Color(0xFF111114),
    this.primaryColor = const Color(0xFF818CF8),
    this.optionBackgroundColor = const Color(0xFF2A2A31),
    this.galleryIconColor = const Color(0xFF60A5FA),
    this.cameraIconColor = const Color(0xFFF472B6),
    this.documentIconColor = const Color(0xFFA78BFA),
    this.scrimColor = const Color(0x99000000),
    this.placeholderColor = const Color(0xFF2A2A31),
    this.bannerColor = const Color(0xFF2A2A31),
    this.selectedOverlayColor = const Color(0x40000000),
    this.borderRadius = 24,
  });

  /// Sheet, header and selection bar background.
  final Color backgroundColor;

  /// Drag handle at the top of the sheet.
  final Color handleColor;

  /// Titles ("Recents", album names, "2 selected").
  final Color textColor;

  /// Option labels, subtitles and hints.
  final Color secondaryTextColor;

  /// Header icons (close, dropdown, multi-select toggle).
  final Color iconColor;

  /// Selection badges, the send button and the active multi-select toggle.
  final Color accentColor;

  /// Icons and text drawn on [accentColor].
  final Color onAccentColor;

  /// Text buttons ("Manage", "Allow access"), checkmarks, progress spinners.
  final Color primaryColor;

  /// Rounded chip behind each option icon (Gallery, Camera, Document).
  final Color optionBackgroundColor;

  final Color galleryIconColor;
  final Color cameraIconColor;
  final Color documentIconColor;

  /// Dims the screen behind the sheet. Fully applied when the gallery is
  /// expanded; the collapsed panel leaves the screen behind undimmed.
  final Color scrimColor;

  /// Thumbnail placeholders while they load.
  final Color placeholderColor;

  /// "Limited access" banner.
  final Color bannerColor;

  /// Drawn over selected thumbnails.
  final Color selectedOverlayColor;

  /// Top corner radius of the sheet.
  final double borderRadius;

  ChatMediaPickerTheme copyWith({
    Color? backgroundColor,
    Color? handleColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? iconColor,
    Color? accentColor,
    Color? onAccentColor,
    Color? primaryColor,
    Color? optionBackgroundColor,
    Color? galleryIconColor,
    Color? cameraIconColor,
    Color? documentIconColor,
    Color? scrimColor,
    Color? placeholderColor,
    Color? bannerColor,
    Color? selectedOverlayColor,
    double? borderRadius,
  }) {
    return ChatMediaPickerTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      handleColor: handleColor ?? this.handleColor,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      iconColor: iconColor ?? this.iconColor,
      accentColor: accentColor ?? this.accentColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      primaryColor: primaryColor ?? this.primaryColor,
      optionBackgroundColor:
          optionBackgroundColor ?? this.optionBackgroundColor,
      galleryIconColor: galleryIconColor ?? this.galleryIconColor,
      cameraIconColor: cameraIconColor ?? this.cameraIconColor,
      documentIconColor: documentIconColor ?? this.documentIconColor,
      scrimColor: scrimColor ?? this.scrimColor,
      placeholderColor: placeholderColor ?? this.placeholderColor,
      bannerColor: bannerColor ?? this.bannerColor,
      selectedOverlayColor: selectedOverlayColor ?? this.selectedOverlayColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
