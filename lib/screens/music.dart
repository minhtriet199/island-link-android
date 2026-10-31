import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// What the PC is playing, with play/pause, next, previous and the volume.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with WatchesPc {
  @override
  String get watchName => 'music';

  Map<String, dynamic> _now = const {};
  int? _vol;
  bool _muted = false;
  late final List<StreamSubscription<Map<String, dynamic>>> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      Link.on('music').listen((m) => setState(() => _now = m)),
      Link.on('levels').listen((m) {
        final v = m['vol'] as int;
        setState(() {
          _vol = v < 0 ? null : v;
          _muted = m['muted'] as bool;
        });
      }),
    ];
    Link.act('levels');
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (_now['title'] as String?) ?? '';
    final artist = (_now['artist'] as String?) ?? '';
    final playing = _now['status'] == 'Playing';
    final text = Theme.of(context).textTheme;
    return CozyPage(
      title: 'Music',
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(color: const Color(0xFFA68BD6), borderRadius: BorderRadius.circular(44)),
            child: const Icon(Icons.music_note_rounded, size: 84, color: Color(0xFFFDFBF4)),
          ),
          const SizedBox(height: 20),
          Text(
            title.isEmpty ? 'Nothing playing' : title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RoundButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous',
                onPressed: () => Link.act('previous'),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Cozy.sun,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Cozy.sunDark, offset: Offset(0, 5))],
                ),
                child: IconButton(
                  iconSize: 40,
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Cozy.ink),
                  tooltip: playing ? 'Pause' : 'Play',
                  onPressed: () => Link.act('play-pause'),
                ),
              ),
              RoundButton(icon: Icons.skip_next_rounded, tooltip: 'Next', onPressed: () => Link.act('next')),
            ],
          ),
          const Spacer(),
          LevelSlider(
            icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            value: _vol,
            onChanged: (v) => Link.act('volume', '$v'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
