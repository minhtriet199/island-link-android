import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// Touchpad and keyboard for the PC. One finger moves, a tap clicks; two fingers scroll,
/// a two-finger tap right-clicks. The box below types live.
class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> with WatchesPc {
  @override
  String get watchName => 'remote';

  static const _speed = 1.8;
  static const _scrollStep = 28.0;
  static const _tapSlop = 12.0;

  final _pointers = <int, Offset>{};
  var _peak = 0; // most fingers down in this touch
  var _moved = 0.0;
  var _pendX = 0.0, _pendY = 0.0, _scroll = 0.0;
  DateTime _downAt = DateTime(0);
  Timer? _flush;

  final _box = TextEditingController();
  String _typed = '';

  @override
  void dispose() {
    _flush?.cancel();
    _box.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (_pointers.isEmpty) {
      _peak = 0;
      _moved = 0;
      _downAt = DateTime.now();
    }
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length > _peak) _peak = _pointers.length;
  }

  void _move(PointerMoveEvent e) {
    final last = _pointers[e.pointer];
    if (last == null) return;
    final d = e.localPosition - last;
    _pointers[e.pointer] = e.localPosition;
    _moved += d.distance;
    if (_pointers.length == 1) {
      _pendX += d.dx * _speed;
      _pendY += d.dy * _speed;
    } else {
      _scroll += d.dy / _pointers.length; // both fingers report: count the gesture once
    }
    _flush ??= Timer(const Duration(milliseconds: 16), _send);
  }

  /// Sends what built up since the last frame; the fraction waits for the next one.
  void _send() {
    _flush = null;
    final x = _pendX.truncate(), y = _pendY.truncate();
    if (x != 0 || y != 0) {
      Link.send({'t': 'm', 'x': x, 'y': y});
      _pendX -= x;
      _pendY -= y;
    }
    final notches = (_scroll / _scrollStep).truncate();
    if (notches != 0) {
      Link.send({'t': 'scroll', 'y': notches});
      _scroll -= notches * _scrollStep;
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    final quick = DateTime.now().difference(_downAt).inMilliseconds < 250;
    if (quick && _moved < _tapSlop) _click(_peak >= 2 ? 'right' : 'left');
  }

  void _click(String button) {
    Link.send({'t': 'btn', 'what': button, 'on': true});
    Link.send({'t': 'btn', 'what': button, 'on': false});
  }

  void _key(String name) => Link.send({'t': 'key', 'what': name});

  /// Types the difference between the box and what's been typed, so keyboards that rewrite words still work.
  void _changed(String now) {
    var same = 0;
    while (same < now.length && same < _typed.length && now.codeUnitAt(same) == _typed.codeUnitAt(same)) {
      same++;
    }
    for (var i = _typed.length; i > same; i--) {
      _key('backspace');
    }
    if (now.length > same) Link.send({'t': 'type', 'text': now.substring(same)});
    _typed = now;
  }

  void _enter() {
    _key('enter');
    _box.clear();
    _typed = '';
  }

  @override
  Widget build(BuildContext context) => CozyPage(
    title: 'Remote',
    resize: true,
    child: Column(
      children: [
        Expanded(
          child: Listener(
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: Container(
              decoration: ShapeDecoration(
                color: const Color(0xFFE6E1D4),
                shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(32)),
              ),
              alignment: Alignment.center,
              child: const Hint(
                'Move with one finger, tap to click.\nTwo fingers scroll, two-finger tap right-clicks.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (label, name) in const [
                ('Esc', 'esc'),
                ('Tab', 'tab'),
                ('←', 'left'),
                ('↑', 'up'),
                ('↓', 'down'),
                ('→', 'right'),
                ('⌫', 'backspace'),
                ('Super', 'super'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(label),
                    backgroundColor: Cozy.card,
                    side: const BorderSide(color: Cozy.cardShadow),
                    onPressed: () => _key(name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _box,
          onChanged: _changed,
          onSubmitted: (_) => _enter(),
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            hintText: 'Type on your PC',
            filled: true,
            fillColor: Cozy.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: const Icon(Icons.keyboard_return_rounded),
              tooltip: 'Enter',
              onPressed: _enter,
            ),
          ),
        ),
      ],
    ),
  );
}
