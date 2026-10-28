import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../link.dart';
import '../theme.dart';

/// Camera view that reads the PC's pairing QR and pairs right away.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // 720p + every frame analysed: the default 640x480 struggles with a dense QR on a terminal.
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1280, 720),
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.map((b) => b.rawValue).firstWhere(Link.looksLikePairCode, orElse: () => null);
    if (code == null) return;

    HapticFeedback.mediumImpact(); // the little "got it" buzz
    setState(() {
      _busy = true;
      _error = null;
    });
    await _camera.stop();
    try {
      await Link.pair(code);
      // The home screen takes over once the link reports in.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on PairException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    final (tag, text, tagColor) = switch ((_busy, _error)) {
      (true, _) => ('Saying hi…', 'Found your PC! Saying hello, this takes a second.', Cozy.sun),
      (_, final String e) => ('Hmm…', e, Cozy.coral),
      _ => ('Almost there', "Point me at the code on your PC screen. I'll do the rest, no typing needed!", Cozy.sky),
    };

    return Scaffold(
      body: DottedPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Text('Scan the code', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _Viewfinder(camera: _camera, onDetect: _onDetect),
              ),
              const SizedBox(height: 30),
              SpeechBubble(tag: tag, text: text, tagColor: tagColor, tilt: 0.04),
              if (_error != null) ...[
                const SizedBox(height: 22),
                BubbleButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _retry),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: Cozy.inkSoft),
                  const SizedBox(width: 6),
                  Text('Only your PC and phone can talk to each other', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded camera window with cream corner brackets and a gently sweeping scan line.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.camera, required this.onDetect});
  final MobileScannerController camera;
  final void Function(BarcodeCapture) onDetect;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Cozy.night,
      borderRadius: BorderRadius.circular(36),
      boxShadow: const [BoxShadow(color: Color(0xFF1F3633), offset: Offset(0, 6))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: MobileScanner(controller: widget.camera, onDetect: widget.onDetect, tapToFocus: true),
        ),
        SizedBox.square(
          dimension: 230,
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (_, _) => CustomPaint(painter: _FramePainter(Curves.easeInOut.transform(_sweep.value))),
          ),
        ),
        Positioned(
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Cozy.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF2F7A55)),
                const SizedBox(width: 8),
                Text('Same Wi-Fi as your PC', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Paint()
      ..color = Cozy.card
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    const arm = 44.0, r = 24.0;
    final w = size.width, h = size.height;
    for (final (dx, dy) in [(0.0, 0.0), (w, 0.0), (0.0, h), (w, h)]) {
      final sx = dx == 0 ? 1.0 : -1.0, sy = dy == 0 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(dx, dy + sy * arm)
          ..lineTo(dx, dy + sy * r)
          ..quadraticBezierTo(dx, dy, dx + sx * r, dy)
          ..lineTo(dx + sx * arm, dy),
        corner,
      );
    }
    final y = 28 + (h - 56) * t;
    canvas.drawRRect(
      RRect.fromLTRBR(28, y - 4, w - 28, y + 4, const Radius.circular(4)),
      Paint()
        ..color = Cozy.sun
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.t != t;
}
