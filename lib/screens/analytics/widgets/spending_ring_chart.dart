import 'dart:math';
import 'package:flutter/material.dart';

class SpendingRingChart extends StatefulWidget {
  final double entPercent;
  final double softPercent;
  final double utilPercent;
  final double otherPercent;
  final double centerValue;
  final String currencySymbol;

  const SpendingRingChart({
    super.key,
    required this.entPercent,
    required this.softPercent,
    required this.utilPercent,
    required this.otherPercent,
    required this.centerValue,
    required this.currencySymbol,
  });

  @override
  State<SpendingRingChart> createState() => _SpendingRingChartState();
}

class _SpendingRingChartState extends State<SpendingRingChart> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SpendingRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entPercent != widget.entPercent ||
        oldWidget.softPercent != widget.softPercent ||
        oldWidget.utilPercent != widget.utilPercent ||
        oldWidget.otherPercent != widget.otherPercent) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: _RingChartPainter(
            entPercent: widget.entPercent * _animationController.value,
            softPercent: widget.softPercent * _animationController.value,
            utilPercent: widget.utilPercent * _animationController.value,
            otherPercent: widget.otherPercent * _animationController.value,
          ),
          child: SizedBox(
            width: 220,
            height: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'AVERAGE',
                  style: TextStyle(
                    color: Color(0xFFACA8A1),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.currencySymbol}${(widget.centerValue / 30.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'per day',
                  style: TextStyle(
                    color: Color(0xFFACA8A1),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RingChartPainter extends CustomPainter {
  final double entPercent;
  final double softPercent;
  final double utilPercent;
  final double otherPercent;

  _RingChartPainter({
    required this.entPercent,
    required this.softPercent,
    required this.utilPercent,
    required this.otherPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    const strokeWidth = 14.0;

    final basePaint = Paint()
      ..color = const Color(0xFFE8E4DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth - 2;

    // Draw background track
    canvas.drawCircle(center, radius, basePaint);

    double startAngle = -pi / 2;

    final categories = [
      (entPercent, const Color(0xFFE50914)), // Red
      (softPercent, const Color(0xFFA259FF)), // Purple
      (utilPercent, const Color(0xFF3395FF)), // Blue
      (otherPercent, const Color(0xFFACA8A1)), // Grey
    ];

    for (final cat in categories) {
      final sweepAngle = cat.$1 * 2 * pi;
      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = cat.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return oldDelegate.entPercent != entPercent ||
        oldDelegate.softPercent != softPercent ||
        oldDelegate.utilPercent != utilPercent ||
        oldDelegate.otherPercent != otherPercent;
  }
}
