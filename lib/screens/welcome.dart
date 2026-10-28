import 'package:flutter/material.dart';

import '../theme.dart';
import 'scan.dart';

/// First screen when the phone isn't paired yet.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.note});

  /// Why we're back here, e.g. the PC forgot this phone.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DottedPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: AppTag()),
              const Expanded(child: Center(child: IslandArt())),
              SpeechBubble(
                tag: note == null ? 'Hi there!' : 'Oh no!',
                text:
                    note ??
                    "Let's meet your PC! On your laptop, open Island's Phone Link to show a code, then scan it here.",
              ),
              const SizedBox(height: 28),
              BubbleButton(
                label: 'Scan PC code',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Island Link" pill with the leaf, top left on the main screens.
class AppTag extends StatelessWidget {
  const AppTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
    decoration: BoxDecoration(
      color: Cozy.card,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [BoxShadow(color: Cozy.cardShadow, offset: Offset(0, 4))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Leaf(),
        const SizedBox(width: 8),
        Text('Island Link', style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

/// A little island with a laptop and a phone joined by a dotted line.
class IslandArt extends StatefulWidget {
  const IslandArt({super.key, this.bob = true});

  /// Gently float up and down (off for small tiles).
  final bool bob;

  @override
  State<IslandArt> createState() => _IslandArtState();
}

class _IslandArtState extends State<IslandArt> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.bob) _bob.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _bob,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_bob.value)), child: child),
      child: CustomPaint(size: const Size(300, 250), painter: _IslandPainter()),
    ),
  );
}

class _IslandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300, size.height / 250);
    final fill = Paint();
    final line = Paint()
      ..color = Cozy.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // water, sand, grass
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 205), width: 280, height: 60),
      fill..color = const Color(0xFFBFE8E2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 200), width: 208, height: 44),
      fill..color = const Color(0xFFF6E3B4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 194), width: 168, height: 30),
      fill..color = const Color(0xFFA8D98A),
    );

    // laptop
    final screen = RRect.fromLTRBR(56, 118, 152, 180, const Radius.circular(10));
    canvas.drawRRect(screen, fill..color = Cozy.card);
    canvas.drawRRect(screen, line);
    canvas.drawRRect(RRect.fromLTRBR(66, 128, 142, 170, const Radius.circular(6)), fill..color = Cozy.sky);
    final base = RRect.fromLTRBR(44, 180, 164, 192, const Radius.circular(6));
    canvas.drawRRect(base, fill..color = Cozy.card);
    canvas.drawRRect(base, line);

    // phone
    final phone = RRect.fromLTRBR(196, 104, 246, 192, const Radius.circular(12));
    canvas.drawRRect(phone, fill..color = Cozy.card);
    canvas.drawRRect(phone, line);
    canvas.drawRRect(RRect.fromLTRBR(204, 116, 238, 174, const Radius.circular(6)), fill..color = Cozy.sun);
    canvas.drawCircle(const Offset(221, 183), 3.5, fill..color = Cozy.ink);

    // the link between them
    final dots = Paint()
      ..color = Cozy.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(156, 128)
      ..cubicTo(170, 92, 190, 92, 200, 108);
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 2), dots);
      }
    }

    // sprout on the laptop + a few sparkles
    canvas.drawPath(
      Path()
        ..moveTo(104, 112)
        ..relativeCubicTo(-2, -20, 10, -34, 30, -38)
        ..relativeCubicTo(-2, 20, -14, 34, -30, 38),
      fill..color = Cozy.leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(104, 112)
        ..relativeCubicTo(-8, -14, -22, -20, -36, -18)
        ..relativeCubicTo(6, 14, 20, 20, 36, 18),
      fill..color = Cozy.leafLight,
    );
    canvas.drawCircle(const Offset(40, 60), 5, fill..color = Cozy.sun);
    canvas.drawCircle(const Offset(262, 46), 7, fill..color = Cozy.sun);
    canvas.drawCircle(const Offset(250, 70), 3.5, fill..color = Cozy.coral);
  }

  @override
  bool shouldRepaint(_IslandPainter old) => false;
}
