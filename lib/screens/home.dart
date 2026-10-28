import 'dart:async';

import 'package:flutter/material.dart';

import '../link.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import 'settings.dart';

/// Home once paired: logo on top, one big rounded panel holding a status row,
/// pages of 3x3 app icons and page dots. Simple and clean.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.link});
  final LinkState link;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _perPage = 9;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _soon(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Cozy.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Text(
            '$name is still growing. Coming soon!',
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  Future<void> _sendFiles() async {
    final n = await Link.pickAndSendFiles();
    if (!mounted || n == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Cozy.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Text(
            n == 1 ? 'Sending 1 file to your PC…' : 'Sending $n files to your PC…',
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  void _settings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  List<AppIcon> get _apps {
    AppIcon app(String name, Art art, Color color, [VoidCallback? onTap]) =>
        AppIcon(label: name, art: art, color: color, size: 76, onTap: onTap ?? () => _soon(name));
    return [
      app('Downloads', Art.downloads, const Color(0xFFF29A7B)),
      app('Remote', Art.remote, const Color(0xFF4FA89E)),
      app('Alerts', Art.alerts, const Color(0xFFE9C46A)),
      app('Music', Art.music, const Color(0xFFA68BD6)),
      app('Power', Art.power, const Color(0xFFE88D7E)),
      app('Terminal', Art.terminal, const Color(0xFF7FA88A)),
      app('Files', Art.files, const Color(0xFF8EC5E8), _sendFiles),
      app('Clipboard', Art.clipboard, const Color(0xFFF3A6C0)),
      app('Settings', Art.settings, const Color(0xFFC9A27E), _settings),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final pageCount = (apps.length / _perPage).ceil();

    return Scaffold(
      body: DottedPaper(
        child: Column(
          children: [
            const SizedBox(height: 14),
            const _Logo(),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                    child: Column(
                      children: [
                        _StatusRow(link: widget.link, onTap: _settings),
                        const SizedBox(height: 18),
                        Expanded(
                          child: PageView.builder(
                            controller: _pages,
                            itemCount: pageCount,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (_, i) => GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.86,
                              children: apps.skip(i * _perPage).take(_perPage).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PageDots(count: pageCount, current: _page),
                      ],
                    ),
                  ),
                  if (_page < pageCount - 1)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 18,
                      child: Center(
                        child: _NextArrow(
                          onTap: () =>
                              _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaf badge + "Island Link", centred.
class _Logo extends StatelessWidget {
  const _Logo();

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

/// Small grey pill with the PC and its status on the left, the time on the right.
class _StatusRow extends StatefulWidget {
  const _StatusRow({required this.link, required this.onTap});
  final LinkState link;
  final VoidCallback onTap;

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Repaint the clock on the minute, not every second.
    _tick = Timer(Duration(seconds: 60 - DateTime.now().second), () {
      if (!mounted) return;
      setState(() {});
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final pc = link.pc ?? 'Your PC';
    final (dot, label) = switch (link.status) {
      LinkStatus.connected => (const Color(0xFF3FA35C), 'Connected'),
      LinkStatus.connecting => (Cozy.sunDark, 'Looking…'),
      _ => (Cozy.coral, 'Offline'),
    };
    const muted = Color(0xFF9C9180);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: '$pc, $label',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
                  decoration: BoxDecoration(color: const Color(0xFFE6E1D4), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '$pc · $label',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF6E6352),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          TimeOfDay.now().format(context),
          style: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 15, color: muted),
        ),
      ],
    );
  }
}

/// Page dots; the current page is a teal ring.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});
  final int count, current;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: i == current ? 20 : 12,
            height: i == current ? 20 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? Colors.transparent : const Color(0xFFD5CFC0),
              border: i == current ? Border.all(color: const Color(0xFF2FB3A4), width: 4) : null,
            ),
          ),
      ],
    ),
  );
}

/// Yellow tab on the panel's edge that flips to the next page.
class _NextArrow extends StatelessWidget {
  const _NextArrow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Next page',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFE9B728),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(23), right: Radius.circular(10)),
        ),
        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFDFBF4), size: 28),
      ),
    ),
  );
}
