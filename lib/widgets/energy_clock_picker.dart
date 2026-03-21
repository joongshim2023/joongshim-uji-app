import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class EnergyClockPicker extends StatefulWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  final bool isActive;

  const EnergyClockPicker({
    Key? key,
    required this.minutes,
    required this.onChanged,
    this.isActive = true,
  }) : super(key: key);

  @override
  _EnergyClockPickerState createState() => _EnergyClockPickerState();
}

class _EnergyClockPickerState extends State<EnergyClockPicker> {
  final List<int> _steps = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
  
  int? _currentDragMinutes;

  int _snapToStep(int m) {
    return _steps.reduce((p, c) => (c - m).abs() < (p - m).abs() ? c : p);
  }

  void _handlePanDown(Offset localPosition, Size size) {
    if (!widget.isActive) return;
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    // Check distance: only respond if touch is near the track rim (wider hit area)
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = size.width / 2 - 20;
    if (distance < radius - 60 || distance > radius + 60) {
      _currentDragMinutes = null;
      return;
    }
    
    _updateDrag(dx, dy, true);
  }

  void _handlePanUpdate(Offset localPosition, Size size) {
    if (!widget.isActive || _currentDragMinutes == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    // No distance check during update - let drag continue even if pointer moves off rim
    _updateDrag(dx, dy, false);
  }

  void _updateDrag(double dx, double dy, bool isStart) {
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    double fraction = angle / (2 * math.pi);
    int rawMinutes = (fraction * 60).round();
    rawMinutes = rawMinutes.clamp(0, 60);

    final currentMin = isStart ? widget.minutes : _currentDragMinutes!;

    // Prevent jumping from 59 to 0 unexpectedly across top boundary
    if (currentMin > 45 && rawMinutes < 15) {
      rawMinutes = 60;
    } else if (currentMin < 15 && rawMinutes > 45) {
      rawMinutes = 0;
    }

    _currentDragMinutes = rawMinutes;

    int snapped = _snapToStep(rawMinutes);
    if (snapped != widget.minutes) {
      widget.onChanged(snapped);
    }
  }

  void _handlePanEnd() {
    _currentDragMinutes = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxWidth);
        return Listener(
          onPointerDown: (event) => _handlePanDown(event.localPosition, size),
          onPointerMove: (event) => _handlePanUpdate(event.localPosition, size),
          onPointerUp: (event) => _handlePanEnd(),
          onPointerCancel: (event) => _handlePanEnd(),
          child: CustomPaint(
            size: size,
            painter: _ClockPainter(
              minutes: widget.minutes,
              isActive: widget.isActive,
            ),
          ),
        );
      },
    );
  }
}

class _ClockPainter extends CustomPainter {
  final int minutes;
  final bool isActive;

  _ClockPainter({required this.minutes, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background Circle
    final bgPaint = Paint()
      ..color = AppTheme.deepNavy.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 20, bgPaint);

    final trackPaint = Paint()
      ..color = AppTheme.timelineBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, radius, trackPaint);

    // Active Arc
    if (minutes > 0 && isActive) {
      final arcPaint = Paint()
        ..color = AppTheme.mutedTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;
        
      double sweepAngle = (minutes / 60) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // Draw ticks
    final tickPaint = Paint()
      ..color = AppTheme.textGray.withOpacity(0.5)
      ..strokeWidth = 1;
    final majorTickPaint = Paint()
      ..color = AppTheme.textGray
      ..strokeWidth = 2;

    for (int i = 5; i <= 60; i += 5) {
      bool isMajor = i % 15 == 0;
      double angle = (i / 60) * 2 * math.pi - math.pi / 2;
      double innerR = isMajor ? radius - 10 : radius - 5;
      double outerR = radius + 12;

      Offset p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      Offset p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);

      if (isMajor && i < 60) {
        TextSpan span = TextSpan(style: const TextStyle(color: AppTheme.textGray, fontSize: 10), text: '$i');
        TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
        tp.layout();
        double lx = center.dx + (outerR + 10) * math.cos(angle) - tp.width / 2;
        double ly = center.dy + (outerR + 10) * math.sin(angle) - tp.height / 2;
        tp.paint(canvas, Offset(lx, ly));
      }
    }

    int pct = ((minutes / 60) * 100).round();
    TextSpan pctSpan = TextSpan(
      style: TextStyle(color: isActive ? AppTheme.activeGreen : AppTheme.textGray, fontSize: 32, fontWeight: FontWeight.bold),
      text: '$pct%',
    );
    TextPainter tpPct = TextPainter(text: pctSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tpPct.layout();

    TextSpan minSpan = TextSpan(
      style: TextStyle(color: isActive ? AppTheme.textWhite : AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.bold),
      text: '$minutes분',
    );
    TextPainter tpMin = TextPainter(text: minSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tpMin.layout();

    // 두 개의 줄간격은 '45분' 글자 높이만큼 간격을 둔다.
    double gap = tpMin.height;
    double totalHeight = tpPct.height + gap + tpMin.height;
    
    double startY = center.dy - totalHeight / 2;
    tpPct.paint(canvas, Offset(center.dx - tpPct.width / 2, startY));
    tpMin.paint(canvas, Offset(center.dx - tpMin.width / 2, startY + tpPct.height + gap));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.minutes != minutes || oldDelegate.isActive != isActive;
  }
}
