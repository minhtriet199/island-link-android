import 'package:flutter/material.dart';

import 'link.dart';
import 'screens/home.dart';
import 'screens/welcome.dart';
import 'theme.dart';

final messenger = GlobalKey<ScaffoldMessengerState>();

/// A small bubble at the bottom of whichever screen is open.
void toast(String text) => messenger.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cozy.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Text(
        text,
        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
      ),
    ),
  );

void main() => runApp(const IslandLinkApp());

class IslandLinkApp extends StatelessWidget {
  const IslandLinkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Island Link',
    debugShowCheckedModeBanner: false,
    theme: Cozy.theme(),
    scaffoldMessengerKey: messenger,
    home: const LinkGate(),
  );
}

/// Shows Welcome until the phone is paired, then Home; follows the link live.
class LinkGate extends StatefulWidget {
  const LinkGate({super.key});

  @override
  State<LinkGate> createState() => _LinkGateState();
}

class _LinkGateState extends State<LinkGate> {
  @override
  void initState() {
    super.initState();
    Link.start(); // paired already? make sure the background link runs
    Link.on('toast').listen((m) => toast(m['msg'] as String));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LinkState>(
    stream: Link.states,
    builder: (context, snap) {
      final link = snap.data;
      if (link == null) return const Scaffold(body: DottedPaper(child: SizedBox.expand()));
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: link.paired
            ? HomeScreen(key: const ValueKey('home'), link: link)
            : WelcomeScreen(key: const ValueKey('welcome'), note: link.error),
      );
    },
  );
}
