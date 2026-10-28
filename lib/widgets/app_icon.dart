// Rounded-square app icons with small flat illustrations, drawn in code (no image assets).
import 'package:flutter/material.dart';

import '../theme.dart';

/// Which little drawing an icon shows.
enum Art { downloads, remote, alerts, music, power, terminal, files, clipboard, settings }

/// One app on the home grid: squircle tile, drawing, label, optional red badge. Squishes when tapped.
class AppIcon extends StatefulWidget {
  const AppIcon({
    super.key,
    required this.label,
    required this.art,
    required this.color,
    required this.onTap,
    this.badge = false,
    this.dimmed = false,
    this.size = 64,
    this.showLabel = true,
  });
  final String label;
  final Art art;
  final Color color;
  final VoidCallback onTap;
  final bool badge;

  /// Not built yet: drawn a bit faded.
  final bool dimmed;

  /// Tile edge in logical pixels; the dock uses bigger tiles without labels.
  final double size;
  final bool showLabel;

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _down ? 0.88 : 1,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutBack,
                child: Opacity(
                  opacity: widget.dimmed ? 0.55 : 1,
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Fill the whole square; without this the tile shrinks to its padding.
                        Positioned.fill(
                          child: Container(
                            decoration: ShapeDecoration(
                              color: widget.color,
                              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(widget.size * 0.32)),
                              shadows: [
                                BoxShadow(
                                  color: Color.lerp(widget.color, Colors.black, 0.18)!,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(widget.size * 0.17),
                            child: CustomPaint(painter: _ArtPainter(widget.art)),
                          ),
                        ),
                        if (widget.badge)
                          Positioned(
                            top: -3,
                            left: -3,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5483B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Cozy.card, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Cozy.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The drawings. Each works on a 52x52 box.
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);
  final Art art;

  static const _ink = Color(0xFF4A3B2E);
  static const _cream = Color(0xFFFFF8E6);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 52);
    final p = Paint()..isAntiAlias = true;
    Paint fill(Color c) => p
      ..color = c
      ..style = PaintingStyle.fill;
    Paint stroke(Color c, double w) => p
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    RRect box(double l, double t, double r, double b, double rad) => RRect.fromLTRBR(l, t, r, b, Radius.circular(rad));

    switch (art) {
      case Art.downloads: // parcel with a big arrow
        canvas.drawRRect(box(8, 22, 44, 46, 6), fill(const Color(0xFFD9A066)));
        canvas.drawRect(const Rect.fromLTRB(23, 22, 29, 46), fill(const Color(0xFFB97F48)));
        canvas.drawPath(
          Path()
            ..moveTo(26, 4)
            ..lineTo(26, 26),
          stroke(_cream, 7),
        );
        canvas.drawPath(
          Path()
            ..moveTo(15, 17)
            ..lineTo(26, 28)
            ..lineTo(37, 17),
          stroke(_cream, 7),
        );
      case Art.remote: // chunky gamepad
        canvas.drawRRect(box(4, 14, 48, 40, 13), fill(_cream));
        canvas.drawRect(const Rect.fromLTRB(11, 25, 23, 29), fill(_ink));
        canvas.drawRect(const Rect.fromLTRB(15, 21, 19, 33), fill(_ink));
        canvas.drawCircle(const Offset(35, 24), 3.4, fill(const Color(0xFFE5483B)));
        canvas.drawCircle(const Offset(41, 30), 3.4, fill(const Color(0xFF3E8ED0)));
      case Art.alerts: // bell with a ringing spark
        canvas.drawPath(
          Path()
            ..moveTo(12, 38)
            ..quadraticBezierTo(15, 34, 15, 25)
            ..arcToPoint(const Offset(37, 25), radius: const Radius.circular(11))
            ..quadraticBezierTo(37, 34, 40, 38)
            ..close(),
          fill(const Color(0xFFFFE08A)),
        );
        canvas.drawCircle(const Offset(26, 42), 4.5, fill(const Color(0xFFD9A066)));
        canvas.drawPath(
          Path()
            ..moveTo(42, 10)
            ..lineTo(46, 6),
          stroke(_cream, 3.5),
        );
        canvas.drawPath(
          Path()
            ..moveTo(44, 16)
            ..lineTo(49, 15),
          stroke(_cream, 3.5),
        );
      case Art.music: // record with a note on top
        canvas.drawCircle(const Offset(24, 30), 17, fill(_ink));
        canvas.drawCircle(const Offset(24, 30), 6, fill(const Color(0xFFF29A7B)));
        canvas.drawPath(
          Path()
            ..moveTo(40, 30)
            ..lineTo(40, 6)
            ..lineTo(49, 10),
          stroke(_cream, 4),
        );
        canvas.drawCircle(const Offset(36, 31), 5.5, fill(_cream));
      case Art.power: // power ring with a little star
        canvas.drawCircle(const Offset(26, 27), 18, stroke(_cream, 6));
        canvas.drawPath(
          Path()
            ..moveTo(26, 4)
            ..lineTo(26, 24),
          stroke(_cream, 6),
        );
        canvas.drawCircle(const Offset(44, 8), 4.5, fill(const Color(0xFFFFE08A)));
      case Art.terminal: // little monitor with a prompt
        canvas.drawRRect(box(4, 8, 48, 40, 8), fill(_ink));
        canvas.drawRRect(box(8, 12, 44, 36, 5), fill(const Color(0xFF2B2F2A)));
        canvas.drawPath(
          Path()
            ..moveTo(13, 19)
            ..lineTo(19, 24)
            ..lineTo(13, 29),
          stroke(const Color(0xFF86C96B), 3.5),
        );
        canvas.drawPath(
          Path()
            ..moveTo(23, 30)
            ..lineTo(33, 30),
          stroke(_cream, 3.5),
        );
        canvas.drawRRect(box(20, 40, 32, 46, 2), fill(_ink));
      case Art.files: // folder with a sheet sticking out
        canvas.drawRRect(box(10, 8, 40, 36, 4), fill(_cream));
        canvas.drawPath(
          Path()
            ..moveTo(4, 18)
            ..lineTo(18, 18)
            ..lineTo(22, 22)
            ..lineTo(48, 22)
            ..lineTo(48, 44)
            ..lineTo(4, 44)
            ..close(),
          fill(const Color(0xFFF7C948)),
        );
      case Art.clipboard: // board with clip and lines
        canvas.drawRRect(box(10, 8, 42, 48, 6), fill(const Color(0xFFB97F48)));
        canvas.drawRRect(box(14, 13, 38, 44, 3), fill(_cream));
        canvas.drawRRect(box(19, 4, 33, 12, 3), fill(_ink));
        for (final y in [22.0, 29.0, 36.0]) {
          canvas.drawLine(Offset(19, y), Offset(33, y), stroke(const Color(0xFFD9C9A6), 3));
        }
      case Art.settings: // two slider knobs
        for (final (y, x, c) in [(16.0, 32.0, const Color(0xFFF29A7B)), (34.0, 18.0, const Color(0xFF8ED6CF))]) {
          canvas.drawLine(Offset(8, y), Offset(44, y), stroke(_cream, 5));
          canvas.drawCircle(Offset(x, y), 7, fill(c));
          canvas.drawCircle(Offset(x, y), 7, stroke(_cream, 3));
        }
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
