import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../widgets/color_slider.dart';
import '../../../routes/media_navigation.dart';

class TextInputResult {
  const TextInputResult(this.text, this.color);

  final String text;
  final Color color;
}

/// Full-screen translucent text entry, shown over the image (WhatsApp "T").
class TextInputPage extends StatefulWidget {
  const TextInputPage({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  static Future<TextInputResult?> open({
    String text = '',
    required Color color,
  }) async {
    return await Get.to<TextInputResult>(
      () => TextInputPage(text: text, color: color),
      opaque: false,
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
  }

  @override
  State<TextInputPage> createState() => _TextInputPageState();
}

class _TextInputPageState extends State<TextInputPage> {
  late final _controller = TextEditingController(text: widget.text);
  late Color _color = widget.color;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() =>
      closeWithResult(TextInputResult(_controller.text.trim(), _color));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  cursorColor: _color,
                  style: TextStyle(
                    color: _color,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration.collapsed(hintText: ''),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: closeRoute,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _done,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 64,
              right: 4,
              child: ColorSlider(
                color: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
