// The cozy look: cream paper, bubbly cards with a solid drop shadow, chunky rounded type.
import 'package:flutter/material.dart';

abstract final class Cozy {
  static const paper = Color(0xFFFBF5E6);
  static const paperDot = Color(0xFFF1E6CC);
  static const card = Color(0xFFFFFDF6);
  static const cardShadow = Color(0xFFE8DCC0);
  static const ink = Color(0xFF5B4A3A);
  static const inkSoft = Color(0xFF7A6450);
  static const leaf = Color(0xFF5FB36A);
  static const leafDark = Color(0xFF3F8A4B);
  static const leafLight = Color(0xFF86C96B);
  static const okBg = Color(0xFFCFEFD2);
  static const okInk = Color(0xFF1F5A35);
  static const sun = Color(0xFFF7D25B);
  static const sunDark = Color(0xFFD9AE2E);
  static const coral = Color(0xFFF29A7B);
  static const sky = Color(0xFF8ED6CF);
  static const night = Color(0xFF2F4F4C);
  static const danger = Color(0xFFA33A2B);

  static ThemeData theme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: leaf, surface: paper),
      scaffoldBackgroundColor: paper,
      fontFamily: 'Nunito',
    );
    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            headlineMedium: const TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 28,
              color: ink,
            ),
            titleLarge: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: 20, color: ink),
            titleMedium: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 17, color: ink),
            bodyLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, height: 1.45, color: ink),
            bodyMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink),
            bodySmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: inkSoft),
          ),
    );
  }
}

/// Cream background with soft polka dots, like notebook paper.
class DottedPaper extends StatelessWidget {
  const DottedPaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DotsPainter(),
    child: SafeArea(child: child),
  );
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Cozy.paper, BlendMode.src);
    final dot = Paint()..color = Cozy.paperDot;
    for (double y = 11; y < size.height; y += 22) {
      for (double x = 11; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 2.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

/// Rounded card that sits on a solid shadow "ledge".
class CozyCard extends StatelessWidget {
  const CozyCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Cozy.card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Cozy.cardShadow, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

/// A card with a tilted name tag on top, like someone talking to you.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.tag, required this.text, this.tagColor = Cozy.coral, this.tilt = -0.05});
  final String tag;
  final String text;
  final Color tagColor;
  final double tilt;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      CozyCard(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
        radius: 30,
        child: SizedBox(
          width: double.infinity,
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
      Positioned(
        top: -16,
        left: 22,
        child: Transform.rotate(
          angle: tilt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(999)),
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF3E2A1E),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Chunky pill button that squishes down onto its ledge when pressed.
class BubbleButton extends StatefulWidget {
  const BubbleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Cozy.sun,
    this.ledge = Cozy.sunDark,
    this.textColor = const Color(0xFF3E3226),
    this.height = 64,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color, ledge, textColor;
  final double height;

  @override
  State<BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<BubbleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    const drop = 6.0;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            height: widget.height + drop,
            child: Stack(
              children: [
                Positioned.fill(
                  top: drop,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.ledge, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  top: _down ? drop : 0,
                  height: widget.height,
                  child: Container(
                    decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(999)),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: widget.textColor, size: 26),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: 21,
                              color: widget.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round cream button for back / settings, also on a ledge.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: const BoxDecoration(
      color: Cozy.card,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Cozy.cardShadow, offset: Offset(0, 4))],
    ),
    child: IconButton(
      icon: Icon(icon, color: Cozy.ink),
      tooltip: tooltip,
      onPressed: onPressed,
    ),
  );
}

/// The little leaf used as the app's mark.
class Leaf extends StatelessWidget {
  const Leaf({super.key, this.size = 26, this.color = Cozy.leaf});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _LeafPainter(color));
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final leaf = Path()
      ..moveTo(5 * s, 19 * s)
      ..cubicTo(5 * s, 11 * s, 11 * s, 6 * s, 19 * s, 5 * s)
      ..cubicTo(18 * s, 13 * s, 13 * s, 19 * s, 5 * s, 19 * s)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.drawLine(
      Offset(5 * s, 19 * s),
      Offset(12 * s, 12 * s),
      Paint()
        ..color = Cozy.ink
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.color != color;
}
