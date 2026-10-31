import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../main.dart' show toast;
import '../theme.dart';
import '../widgets/page.dart';

/// The PC's Download mode: start it, watch the progress, choose what happens when it's done.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Map<String, dynamic>? _s;
  late final StreamSubscription<Map<String, dynamic>> _sub;

  @override
  void initState() {
    super.initState();
    Link.lastDownload().then((s) {
      if (mounted && _s == null) setState(() => _s = s);
    });
    _sub = Link.on('dl').listen((m) => setState(() => _s = m['s'] as Map<String, dynamic>));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _do(String what) async {
    if (!await Link.act(what)) toast("Your PC isn't connected.");
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return CozyPage(
      title: 'Downloads',
      child: s != null && s['asking'] == true
          ? _Asking(s: s, act: _do)
          : s != null && s['on'] == true
          ? _Running(s: s, act: _do)
          : _Idle(act: _do),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.act});
  final ValueChanged<String> act;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      const SizedBox(height: 16),
      const Icon(Icons.cloud_download_rounded, size: 72, color: Color(0xFFF29A7B)),
      const SizedBox(height: 12),
      Text('Download mode is off', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Hint('Your PC dims its screens and saves power while something downloads.'),
      const SizedBox(height: 24),
      BubbleButton(label: 'Start, shut down after', onPressed: () => act('dl.start-shutdown')),
      const SizedBox(height: 14),
      BubbleButton(
        label: 'Start, keep PC on',
        color: Cozy.sky,
        ledge: const Color(0xFF5FB3AB),
        onPressed: () => act('dl.start-keep'),
      ),
    ],
  );
}

class _Running extends StatelessWidget {
  const _Running({required this.s, required this.act});
  final Map<String, dynamic> s;
  final ValueChanged<String> act;

  String get _status {
    final quiet = (s['quiet'] as num?)?.toInt() ?? 0;
    final speed = (s['speed'] as num?)?.toDouble() ?? 0;
    if ((s['items'] as List).isNotEmpty) return speedText(speed);
    if (speed > 150000) return 'Downloading · ${speedText(speed)}';
    if (s['saw'] != true) return 'Waiting for a download to start…';
    return 'Finishing up… done in ${(60 - quiet).clamp(0, 60)} s';
  }

  @override
  Widget build(BuildContext context) {
    final keep = s['after'] == 'keep';
    final items = (s['items'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final item in items) ...[_Item(item), const SizedBox(height: 16)],
              Hint(_status),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Shut down after')),
            ButtonSegment(value: true, label: Text('Keep PC on')),
          ],
          selected: {keep},
          onSelectionChanged: (v) => act(v.first ? 'dl.after-keep' : 'dl.after-shutdown'),
        ),
        const SizedBox(height: 12),
        BubbleButton(
          label: 'Stop Download mode',
          color: Cozy.card,
          ledge: Cozy.cardShadow,
          textColor: Cozy.danger,
          height: 56,
          onPressed: () => act('dl.stop'),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final done = (item['done'] as num?)?.toDouble() ?? 0;
    final total = (item['total'] as num?)?.toDouble() ?? 0;
    final installing = item['installing'] == true;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item['name'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
            if (total > 0) Text('${(done / total * 100).floor()}%', style: text.bodyMedium),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: total > 0 ? (done / total).clamp(0, 1) : null,
            backgroundColor: Cozy.cardShadow,
            color: Cozy.leaf,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          installing
              ? '${item['app']} · Installing…'
              : '${item['app']}${total > 0 ? ' · ${sizeText(done)} of ${sizeText(total)}' : ''}',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _Asking extends StatelessWidget {
  const _Asking({required this.s, required this.act});
  final Map<String, dynamic> s;
  final ValueChanged<String> act;

  @override
  Widget build(BuildContext context) {
    final left = (s['countdown'] as num?)?.toInt() ?? 0;
    final names = ((s['names'] as List?) ?? const []).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text('Downloads finished', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (names.isNotEmpty) Hint(names),
        const SizedBox(height: 18),
        Text(
          '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: 64, color: Cozy.ink),
        ),
        const Hint('until your PC shuts down'),
        const Spacer(),
        BubbleButton(label: 'Keep using', onPressed: () => act('dl.keep')),
        const SizedBox(height: 14),
        BubbleButton(
          label: 'Shut down now',
          color: Cozy.card,
          ledge: Cozy.cardShadow,
          textColor: Cozy.danger,
          height: 56,
          onPressed: () => act('dl.shutdown'),
        ),
      ],
    );
  }
}

String sizeText(double b) => b >= 1073741824
    ? '${(b / 1073741824).toStringAsFixed(1)} GB'
    : b >= 1048576
    ? '${(b / 1048576).round()} MB'
    : '${(b / 1024).round()} KB';

String speedText(double b) => b >= 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB/s' : '${(b / 1024).round()} KB/s';
