import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// One visible kitty window on the PC, mirrored here. The PC must allow it (Island → Phone Link)
/// and the phone asks for your fingerprint every time this screen opens.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

enum _Gate { checking, notAllowed, refused, open }

class _TerminalScreenState extends State<TerminalScreen> {
  var _gate = _Gate.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _gate = _Gate.checking);
    final allowed = await Link.terminalAllowed();
    final ok = allowed && await Link.authenticate('Open a terminal on your PC');
    if (mounted) setState(() => _gate = !allowed ? _Gate.notAllowed : (ok ? _Gate.open : _Gate.refused));
  }

  @override
  Widget build(BuildContext context) => CozyPage(
    title: 'Terminal',
    resize: true,
    child: switch (_gate) {
      _Gate.open => const _Live(),
      _Gate.checking => const Center(child: CircularProgressIndicator(color: Cozy.leaf)),
      _Gate.notAllowed => const Center(
        child: Hint('The terminal is off.\nTurn it on in Island: Settings → Phone Link.'),
      ),
      _Gate.refused => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Hint('The fingerprint check was cancelled.'),
            const SizedBox(height: 16),
            BubbleButton(label: 'Try again', onPressed: _check),
          ],
        ),
      ),
    },
  );
}

class _Live extends StatefulWidget {
  const _Live();

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> with WatchesPc {
  @override
  String get watchName => 'term';

  static double _textSize = 15; // kept while the app runs

  bool _on = false;
  String _screen = '';
  final _box = TextEditingController();
  late final StreamSubscription<Map<String, dynamic>> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Link.on('term').listen(
      (m) => setState(() {
        _on = m['on'] == true;
        _screen = ((m['text'] as String?) ?? '').trimRight();
      }),
    );
    Link.send({'t': 'term', 'what': 'open'});
  }

  @override
  void dispose() {
    _sub.cancel();
    _box.dispose();
    super.dispose();
  }

  void _resize(int by) => setState(() => _textSize = (_textSize + by).clamp(10, 24));

  Widget _chip(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      label: Text(label),
      backgroundColor: Cozy.card,
      side: const BorderSide(color: Cozy.cardShadow),
      onPressed: onPressed,
    ),
  );

  void _raw(String text) => Link.send({'t': 'term', 'text': text});

  void _enter() {
    _raw('${_box.text}\r');
    _box.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: Cozy.night,
            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                _on ? _screen : 'The window is closed.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _textSize,
                  color: const Color(0xFFE8F3EC),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.keyboard_return_rounded, size: 18, color: Cozy.ink),
                label: const Text('Enter'),
                backgroundColor: Cozy.sun,
                side: const BorderSide(color: Cozy.sunDark),
                onPressed: _enter,
              ),
            ),
            for (final (label, text) in const [
              ('Ctrl+C', '\u0003'),
              ('Tab', '\t'),
              ('↑', '\u001b[A'),
              ('↓', '\u001b[B'),
              ('Esc', '\u001b'),
              ('Ctrl+D', '\u0004'),
            ])
              _chip(label, () => _raw(text)),
            _chip('A−', () => _resize(-1)),
            _chip('A+', () => _resize(1)),
            _chip(_on ? 'Close window' : 'Open again', () => Link.send({'t': 'term', 'what': _on ? 'close' : 'open'})),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _box,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _enter(),
        textInputAction: TextInputAction.send,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: _on ? 'Command' : 'Closed',
          filled: true,
          fillColor: Cozy.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), tooltip: 'Send', onPressed: _enter),
        ),
      ),
    ],
  );
}
