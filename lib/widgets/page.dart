// The clean Home look, shared by every screen: logo or title on top, one big rounded panel below.
import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';

/// Leaf badge + "Island Link", centred.
class IslandLogo extends StatelessWidget {
  const IslandLogo({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: Color(0xFF2F6B45), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Leaf(size: 24, color: Color(0xFFFDFBF4)),
      ),
      const SizedBox(width: 10),
      const Text(
        'Island Link',
        style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: 30, color: Color(0xFF2F6B45)),
      ),
    ],
  );
}

/// The big soft rounded panel.
class CozyPanel extends StatelessWidget {
  const CozyPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
    decoration: ShapeDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDFBF4), Color(0xFFECE7DA)],
      ),
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(48)),
      shadows: const [BoxShadow(color: Color(0x1F5B4A3A), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

/// A feature screen: back button + title, then the panel.
class CozyPage extends StatelessWidget {
  const CozyPage({super.key, required this.title, required this.child, this.resize = false});
  final String title;
  final Widget child;
  final bool resize; // screens with a text box move up for the keyboard

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: resize,
    body: DottedPaper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Row(
              children: [
                RoundButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 14),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          Expanded(child: CozyPanel(child: child)),
        ],
      ),
    ),
  );
}

/// Tells the PC a screen is open, and not while the app is in the background, so what feeds
/// it (playerctl, the terminal mirror, the virtual mouse) only runs while you're looking.
mixin WatchesPc<T extends StatefulWidget> on State<T> {
  String get watchName;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    Link.watch(watchName, true);
    _life = AppLifecycleListener(onShow: () => Link.watch(watchName, true), onHide: () => Link.watch(watchName, false));
  }

  @override
  void dispose() {
    _life.dispose();
    Link.watch(watchName, false);
    super.dispose();
  }
}

/// Grey-toned note inside a panel.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall);
}

/// Warm slider used for volume and brightness: follows your finger, tells the PC a few times a second.
class LevelSlider extends StatefulWidget {
  const LevelSlider({super.key, required this.icon, required this.value, required this.onChanged, this.min = 0});
  final IconData icon;
  final int? value; // null until the PC has answered
  final ValueChanged<int> onChanged;
  final int min;

  @override
  State<LevelSlider> createState() => _LevelSliderState();
}

class _LevelSliderState extends State<LevelSlider> {
  double? _drag;
  int _lastSent = 0;
  DateTime _sentAt = DateTime(0);

  void _send(double v, {bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_sentAt).inMilliseconds < 150) return;
    if (v.round() == _lastSent) return;
    _lastSent = v.round();
    _sentAt = now;
    widget.onChanged(_lastSent);
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(widget.icon, color: Cozy.inkSoft),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Cozy.leaf,
            inactiveTrackColor: Cozy.cardShadow,
            thumbColor: Cozy.leafDark,
            trackHeight: 10,
          ),
          child: Slider(
            min: widget.min.toDouble(),
            max: 100,
            value: (_drag ?? widget.value?.toDouble() ?? widget.min.toDouble()).clamp(widget.min.toDouble(), 100),
            onChanged: widget.value == null
                ? null
                : (v) {
                    setState(() => _drag = v);
                    _send(v);
                  },
            onChangeEnd: (v) {
              _send(v, force: true);
              setState(() => _drag = null);
            },
          ),
        ),
      ),
    ],
  );
}
