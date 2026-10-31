import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../link.dart';
import '../main.dart' show toast;
import '../theme.dart';
import '../widgets/page.dart';

/// Moves text between the two clipboards when you ask. Android doesn't let an app read the
/// clipboard in the background, and nothing should move on its own anyway.
class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  String? _fromPc;
  late final StreamSubscription<Map<String, dynamic>> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Link.on('clip').listen((m) async {
      final text = (m['text'] as String?) ?? '';
      if (text.isEmpty) return toast('No text on the PC clipboard.');
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) setState(() => _fromPc = text);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) return toast('Nothing to send: copy some text first.');
    if (text.length > 100000) return toast("That's too long to send this way. Use Files.");
    toast(await Link.send({'t': 'clip', 'text': text}) ? 'On your PC clipboard.' : "Your PC isn't connected.");
  }

  Future<void> _get() async {
    if (!await Link.send({'t': 'clipget'})) toast("Your PC isn't connected.");
  }

  @override
  Widget build(BuildContext context) => CozyPage(
    title: 'Clipboard',
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        BubbleButton(label: 'Send to PC', icon: Icons.upload_rounded, onPressed: _send),
        const SizedBox(height: 16),
        BubbleButton(
          label: 'Get from PC',
          icon: Icons.download_rounded,
          color: Cozy.sky,
          ledge: const Color(0xFF5FB3AB),
          onPressed: _get,
        ),
        const SizedBox(height: 22),
        if (_fromPc != null) ...[
          const Hint('Copied to this phone:'),
          const SizedBox(height: 8),
          CozyCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              _fromPc!,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ] else
          const Hint('Copy something on one side, then press a button here.'),
      ],
    ),
  );
}
