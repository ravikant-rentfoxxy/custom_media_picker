import 'package:flutter/material.dart';

/// WhatsApp-style vertical gradient color picker.
class ColorSlider extends StatelessWidget {
  const ColorSlider({
    super.key,
    required this.color,
    required this.onChanged,
    this.height = 240,
  });

  static const colors = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF5AC8FA),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
  ];

  final Color color;
  final ValueChanged<Color> onChanged;
  final double height;

  Color _colorAt(double dy) {
    final t = (dy / height).clamp(0.0, 1.0);
    final pos = t * (colors.length - 1);
    final i = pos.floor();
    final next = (i + 1).clamp(0, colors.length - 1);
    return Color.lerp(colors[i], colors[next], pos - i)!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onChanged(_colorAt(d.localPosition.dy)),
          onVerticalDragDown: (d) => onChanged(_colorAt(d.localPosition.dy)),
          onVerticalDragUpdate: (d) => onChanged(_colorAt(d.localPosition.dy)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 18,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
