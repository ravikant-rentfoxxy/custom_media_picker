import 'package:chat_media_picker/chat_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  ChatMediaPicker.config = const ChatMediaPickerConfig(
    maxSelection: 10,
    recipientName: 'Sample Chat',
  );
  // The picker navigates with GetX, so the app must use GetMaterialApp.
  runApp(const GetMaterialApp(home: ExamplePage()));
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _media = <PickedMedia>[];

  Future<void> _pick(Future<List<PickedMedia>?> picker) async {
    final picked = await picker;
    if (picked == null || !mounted) return; // Closed by the user.
    setState(() => _media.addAll(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('chat_media_picker')),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _media.length,
        itemBuilder: (_, i) => _Tile(media: _media[i]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ChatMediaPicker.openGallery()),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ChatMediaPicker.openCamera()),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.media});

  final PickedMedia media;

  @override
  Widget build(BuildContext context) {
    final thumbnail = media.thumbnail;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!media.isVideo)
          Image.file(media.file, fit: BoxFit.cover, cacheWidth: 300)
        else if (thumbnail != null)
          Image.memory(thumbnail, fit: BoxFit.cover)
        else
          const ColoredBox(color: Colors.black12),
        if (media.isVideo)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                formatDuration(media.duration),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (media.caption.isNotEmpty)
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              color: Colors.black45,
              padding: const EdgeInsets.all(4),
              child: Text(
                media.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
