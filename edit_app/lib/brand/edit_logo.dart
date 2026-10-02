import 'package:flutter/material.dart';

/// Logo Edit: E nera in cerchio verde con sfumatura scuro → chiaro.
class EditLogo extends StatelessWidget {
  const EditLogo({super.key, this.size = 40});

  final double size;

  static const Color green = Color(0xFF5DA84A);
  static const Color greenDark = Color(0xFF2F6B28);
  static const Color greenLight = Color(0xFF9FD68A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _EditLogoPainter(),
      ),
    );
  }
}

class _EditLogoPainter extends CustomPainter {
  const _EditLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          EditLogo.greenDark,
          EditLogo.green,
          EditLogo.greenLight,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawCircle(rect.center, size.shortestSide / 2, circle);

    // Leggero highlight in alto per volume.
    final highlight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.shortestSide / 2, highlight);

    final tp = TextPainter(
      text: TextSpan(
        text: 'E',
        style: TextStyle(
          color: Colors.black,
          fontSize: size.shortestSide * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
