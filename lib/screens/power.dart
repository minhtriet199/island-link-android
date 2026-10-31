import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../main.dart' show toast;
import '../theme.dart';
import '../widgets/page.dart';

/// Lock, sleep, restart or shut down the PC, plus its screen brightness.
class PowerScreen extends StatefulWidget {
  const PowerScreen({super.key});

  @override
  State<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends State<PowerScreen> {
  int? _bright;
  late final StreamSubscription<Map<String, dynamic>> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Link.on('levels').listen((m) {
      final b = m['bright'] as int;
      setState(() => _bright = b < 0 ? null : b);
    });
    Link.act('levels');
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _run(String what, String label, {bool ask = true}) async {
    if (ask) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Cozy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('$label your PC?', style: Theme.of(context).textTheme.titleLarge),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(label, style: const TextStyle(color: Cozy.danger)),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    if (!await Link.act(what)) toast("Your PC isn't connected.");
  }

  @override
  Widget build(BuildContext context) => CozyPage(
    title: 'Power',
    child: Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              _Tile('Lock', Icons.lock_rounded, const Color(0xFF8EC5E8), () => _run('lock', 'Lock', ask: false)),
              _Tile('Sleep', Icons.bedtime_rounded, const Color(0xFFA68BD6), () => _run('suspend', 'Sleep')),
              _Tile('Restart', Icons.restart_alt_rounded, const Color(0xFFE9C46A), () => _run('reboot', 'Restart')),
              _Tile('Shut down', Icons.power_settings_new_rounded, const Color(0xFFE88D7E), () {
                _run('shutdown', 'Shut down');
              }),
            ],
          ),
        ),
        LevelSlider(
          icon: Icons.light_mode_rounded,
          value: _bright,
          min: 2,
          onChanged: (v) => Link.act('brightness', '$v'),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(34)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: const Color(0xFFFDFBF4)),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFFFDFBF4))),
        ],
      ),
    ),
  );
}
