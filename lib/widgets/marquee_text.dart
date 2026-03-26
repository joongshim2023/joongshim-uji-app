import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed; // pixels per second

  const MarqueeText({
    Key? key,
    required this.text,
    required this.style,
    this.speed = 30.0,
  }) : super(key: key);

  @override
  _MarqueeTextState createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _containerWidth = 0.0;
  double _textWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  void _calculateDuration() {
    if (_containerWidth == 0.0 || _textWidth == 0.0) return;
    final totalDistance = _containerWidth + _textWidth;
    final duration = Duration(milliseconds: (totalDistance / widget.speed * 1000).toInt());
    if (_controller.duration != duration) {
      _controller.duration = duration;
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _textWidth = 0.0; // Force recalculation
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDuration());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 0 && constraints.maxWidth != _containerWidth) {
          _containerWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDuration());
        }

        // Measure actual text width using TextPainter
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        
        if (_textWidth != textPainter.width) {
          _textWidth = textPainter.width;
          WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDuration());
        }

        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // start at dx = _containerWidth (off screen right)
                // end at dx = -_textWidth (off screen left)
                double dx = _containerWidth - (_controller.value * (_containerWidth + _textWidth));
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
