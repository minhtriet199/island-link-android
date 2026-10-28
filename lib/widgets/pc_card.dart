import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';

/// "Gamer's PC — Connected" card with a status dot.
class PcCard extends StatelessWidget {
  const PcCard({super.key, required this.link});
  final LinkState link;

  @override
  Widget build(BuildContext context) {
    final (label, dot, ring, ink) = switch (link.status) {
      LinkStatus.connected => ('Connected · same Wi-Fi', const Color(0xFF3FA35C), Cozy.okBg, const Color(0xFF2F7A55)),
      LinkStatus.connecting => ('Looking for your PC…', Cozy.sunDark, const Color(0xFFFBEFC4), const Color(0xFF7A5A12)),
      _ => ("Can't reach it, trying again", Cozy.coral, const Color(0xFFFBD9CE), const Color(0xFF8A2F1F)),
    };
    return CozyCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Cozy.okBg, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.laptop_rounded, color: Color(0xFF2F7A55), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.pc ?? 'Your PC',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _PulseDot(color: dot, ring: ring, pulse: link.status == LinkStatus.connected),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Leaf(size: 34, color: Cozy.leafLight),
        ],
      ),
    );
  }
}

/// Status dot; breathes softly while connected.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.ring, required this.pulse});
  final Color color, ring;
  final bool pulse;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.pulse) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: widget.ring, spreadRadius: 2 + 3 * _c.value)],
      ),
    ),
  );
}
