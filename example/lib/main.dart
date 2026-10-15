import 'package:chat_media_picker/chat_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  // The picker navigates with GetX, so the app must use GetMaterialApp.
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatPage(),
    );
  }
}

/// A simple chat screen: the attach and camera buttons of the input bar open
/// the picker, and picked media are "sent" as bubbles.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _messages = <_Message>[
    _Message.text('Morning! How was the trip?'),
    _Message.text('So good. The views were unreal', outgoing: true),
    _Message.text('Share some pictures 😄'),
    _Message.text('Picking a few now', outgoing: true),
  ];

  // Picker options, changed from the app bar menu.
  var _gallery = true;
  var _camera = true;
  var _files = true;
  var _dark = false;

  _Palette get _palette => _dark ? _Palette.dark : _Palette.light;

  ChatMediaPickerConfig get _config => ChatMediaPickerConfig(
    maxSelection: 10,
    recipientName: 'Alex Morgan',
    enableGallery: _gallery,
    enableCamera: _camera,
    enableFilePicker: _files,
    theme: _dark
        ? const ChatMediaPickerTheme.dark()
        : const ChatMediaPickerTheme(),
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<List<PickedMedia>?> Function() picker) async {
    ChatMediaPicker.config = _config;
    final picked = await picker();
    if (picked == null || !mounted) return; // Closed by the user.
    // Photos and videos sent together become one album bubble.
    final visual = picked.where((m) => !m.isFile).toList();
    setState(() {
      if (visual.isNotEmpty) _messages.add(_Message.media(visual));
      _messages.addAll(
        picked.where((m) => m.isFile).map((m) => _Message.media([m])),
      );
    });
  }

  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(_Message.text(text, outgoing: true)));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Scaffold(
      backgroundColor: palette.chatBackground,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: palette.border)),
        leading: const Icon(Icons.arrow_back_ios_new, size: 20),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: palette.accent.withValues(alpha: .15),
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alex Morgan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Active now',
                  style: TextStyle(fontSize: 12, color: palette.subtitle),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const Icon(Icons.info_outline),
          _OptionsMenu(
            gallery: _gallery,
            camera: _camera,
            files: _files,
            dark: _dark,
            onChanged: (option) => setState(() {
              switch (option) {
                case 'gallery':
                  _gallery = !_gallery;
                case 'camera':
                  _camera = !_camera;
                case 'files':
                  _files = !_files;
                case 'dark':
                  _dark = !_dark;
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(
                message: _messages[_messages.length - 1 - i],
                palette: palette,
              ),
            ),
          ),
          _InputBar(
            controller: _input,
            palette: palette,
            onAttach: () => _pick(ChatMediaPicker.openGallery),
            onCamera: () => _pick(ChatMediaPicker.openCamera),
            onSend: _sendText,
          ),
        ],
      ),
    );
  }
}

class _OptionsMenu extends StatelessWidget {
  const _OptionsMenu({
    required this.gallery,
    required this.camera,
    required this.files,
    required this.dark,
    required this.onChanged,
  });

  final bool gallery;
  final bool camera;
  final bool files;
  final bool dark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'gallery',
          checked: gallery,
          child: const Text('Gallery'),
        ),
        CheckedPopupMenuItem(
          value: 'camera',
          checked: camera,
          child: const Text('Camera'),
        ),
        CheckedPopupMenuItem(
          value: 'files',
          checked: files,
          child: const Text('Documents'),
        ),
        CheckedPopupMenuItem(
          value: 'dark',
          checked: dark,
          child: const Text('Dark theme'),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.palette,
    required this.onAttach,
    required this.onCamera,
    required this.onSend,
  });

  final TextEditingController controller;
  final _Palette palette;
  final VoidCallback onAttach;
  final VoidCallback onCamera;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('attach'),
                style: IconButton.styleFrom(
                  backgroundColor: palette.accent.withValues(alpha: .12),
                  foregroundColor: palette.accent,
                ),
                icon: const Icon(Icons.add),
                onPressed: onAttach,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                    color: palette.inputField,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: TextStyle(color: palette.text),
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: TextStyle(color: palette.icon),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('camera'),
                        icon: Icon(
                          Icons.photo_camera_outlined,
                          color: palette.icon,
                        ),
                        onPressed: onCamera,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_upward),
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message {
  _Message.text(String this.text, {this.outgoing = false}) : media = const [];
  _Message.media(this.media) : text = null, outgoing = true;

  final String? text;

  /// One file, or one or more photos/videos (an album).
  final List<PickedMedia> media;
  final bool outgoing;
  final time = TimeOfDay.now();
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.palette});

  final _Message message;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final outgoing = message.outgoing;
    final palette = outgoing ? this.palette.onOutgoing : this.palette;
    final media = message.media;
    final caption = message.text ?? '';
    final time = Text(
      message.time.format(context),
      style: TextStyle(fontSize: 11, color: palette.time),
    );

    Widget content;
    if (media.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(caption, style: TextStyle(fontSize: 16, color: palette.text)),
            time,
          ],
        ),
      );
    } else if (media.first.isFile) {
      content = _FileContent(media: media.first, palette: palette, time: time);
    } else {
      content = _MediaContent(media: media, palette: palette, time: time);
    }

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .75,
        ),
        decoration: BoxDecoration(
          color: outgoing ? palette.outgoing : palette.incoming,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(outgoing ? 18 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 18),
          ),
        ),
        child: content,
      ),
    );
  }
}

class _MediaContent extends StatelessWidget {
  const _MediaContent({
    required this.media,
    required this.palette,
    required this.time,
  });

  static const _width = 240.0;
  static const _gap = 3.0;

  final List<PickedMedia> media;
  final _Palette palette;
  final Widget time;

  @override
  Widget build(BuildContext context) {
    final caption = media
        .map((m) => m.caption)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    const half = (_width - _gap) / 2;
    final shown = media.take(4).toList();
    final extra = media.length - shown.length;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                if (media.length == 1)
                  _MediaTile(media: media.first, width: _width, height: 260)
                else
                  // Album: 2 x 2 grid; a third item spans the full width.
                  SizedBox(
                    width: _width,
                    child: Wrap(
                      spacing: _gap,
                      runSpacing: _gap,
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          _MediaTile(
                            media: shown[i],
                            width: shown.length == 3 && i == 2 ? _width : half,
                            height: half,
                            more: i == 3 && extra > 0 ? extra : 0,
                          ),
                      ],
                    ),
                  ),
                if (caption.isEmpty)
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: time,
                    ),
                  ),
              ],
            ),
          ),
          if (caption.isNotEmpty)
            SizedBox(
              width: _width,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      caption,
                      style: TextStyle(fontSize: 16, color: palette.text),
                    ),
                    time,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.width,
    required this.height,
    this.more = 0,
  });

  final PickedMedia media;
  final double width;
  final double height;

  /// Items not shown in the album ("+3" overlay).
  final int more;

  @override
  Widget build(BuildContext context) {
    final thumbnail = media.thumbnail;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!media.isVideo)
            Image.file(media.file, fit: BoxFit.cover, cacheWidth: 600)
          else if (thumbnail != null)
            Image.memory(thumbnail, fit: BoxFit.cover)
          else
            const ColoredBox(color: Colors.black26),
          if (media.isVideo)
            const Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow, color: Colors.white),
              ),
            ),
          if (more > 0)
            ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Text(
                  '+$more',
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({
    required this.media,
    required this.palette,
    required this.time,
  });

  final PickedMedia media;
  final _Palette palette;
  final Widget time;

  @override
  Widget build(BuildContext context) {
    final size = media.size;
    final extension = media.fileName.contains('.')
        ? media.fileName.split('.').last.toUpperCase()
        : 'FILE';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.fileBox,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: palette.text, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.text),
                      ),
                      Text(
                        [
                          if (size != null) formatFileSize(size),
                          extension,
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: palette.time),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(0, 4, 6, 2), child: time),
        ],
      ),
    );
  }
}

/// Colours of the example chat (not part of the package).
class _Palette {
  const _Palette({
    required this.accent,
    required this.surface,
    required this.onSurface,
    required this.subtitle,
    required this.border,
    required this.chatBackground,
    required this.incoming,
    required this.outgoing,
    required this.text,
    required this.time,
    required this.inputField,
    required this.icon,
    required this.fileBox,
  });

  static const light = _Palette(
    accent: Color(0xFF4F46E5),
    surface: Colors.white,
    onSurface: Color(0xFF18181B),
    subtitle: Color(0xFF71717A),
    border: Color(0xFFE4E4E7),
    chatBackground: Color(0xFFF7F7FA),
    incoming: Color(0xFFE9E9EF),
    outgoing: Color(0xFF4F46E5),
    text: Color(0xFF18181B),
    time: Color(0xFF71717A),
    inputField: Color(0xFFF1F2F6),
    icon: Color(0xFF8B8B95),
    fileBox: Color(0x0F000000),
  );

  static const dark = _Palette(
    accent: Color(0xFF818CF8),
    surface: Color(0xFF1C1C21),
    onSurface: Color(0xFFF2F2F5),
    subtitle: Color(0xFF9A9AA5),
    border: Color(0xFF2A2A31),
    chatBackground: Color(0xFF131316),
    incoming: Color(0xFF26262D),
    outgoing: Color(0xFF4F46E5),
    text: Color(0xFFF2F2F5),
    time: Color(0xFF9A9AA5),
    inputField: Color(0xFF26262D),
    icon: Color(0xFF8B8B95),
    fileBox: Color(0x1FFFFFFF),
  );

  final Color accent;
  final Color surface;
  final Color onSurface;
  final Color subtitle;
  final Color border;
  final Color chatBackground;
  final Color incoming;
  final Color outgoing;
  final Color text;
  final Color time;
  final Color inputField;
  final Color icon;
  final Color fileBox;

  /// Text colours for content drawn on [outgoing].
  _Palette get onOutgoing => _Palette(
    accent: accent,
    surface: surface,
    onSurface: onSurface,
    subtitle: subtitle,
    border: border,
    chatBackground: chatBackground,
    incoming: incoming,
    outgoing: outgoing,
    text: Colors.white,
    time: const Color(0xB3FFFFFF),
    inputField: inputField,
    icon: icon,
    fileBox: const Color(0x26FFFFFF),
  );
}
