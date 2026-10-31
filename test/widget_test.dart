import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:island_link/link.dart';
import 'package:island_link/screens/alerts.dart';
import 'package:island_link/screens/downloads.dart';
import 'package:island_link/screens/home.dart';
import 'package:island_link/screens/music.dart';
import 'package:island_link/screens/power.dart';
import 'package:island_link/screens/terminal.dart';
import 'package:island_link/screens/welcome.dart';
import 'package:island_link/theme.dart';
import 'package:island_link/widgets/app_icon.dart';

Widget _app(Widget child) => MaterialApp(theme: Cozy.theme(), home: child);

/// Stands in for the native side: answers method calls and records what goes to the PC.
List<Map<String, dynamic>> _fakeNative(WidgetTester tester, {Map<String, Object?> answers = const {}}) {
  final sent = <Map<String, dynamic>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('island_link/link'), (call) async {
    if (call.method == 'send') {
      sent.add(jsonDecode(call.arguments as String) as Map<String, dynamic>);
      return true;
    }
    return answers[call.method];
  });
  tester.binding.defaultBinaryMessenger.setMockStreamHandler(
    const EventChannel('island_link/msg'),
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
  return sent;
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2424);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('welcome invites the user to scan', (tester) async {
    await tester.pumpWidget(_app(const WelcomeScreen()));
    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan PC code'), findsOneWidget);
  });

  testWidgets('welcome explains when the PC forgot the phone', (tester) async {
    await tester.pumpWidget(_app(const WelcomeScreen(note: 'Your PC forgot this phone.')));
    expect(find.text('Oh no!'), findsOneWidget);
    expect(find.text('Your PC forgot this phone.'), findsOneWidget);
  });

  testWidgets('home shows the PC and its link status', (tester) async {
    tester.view.physicalSize = const Size(1080, 2424); // Pixel 9
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const HomeScreen(link: LinkState(LinkStatus.connected, pc: 'Gamer'))));
    expect(find.bySemanticsLabel('Gamer, Connected'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  test('only Island Link codes are accepted', () {
    expect(Link.looksLikePairCode('islandlink://pair?v=1&h=1.2.3.4'), isTrue);
    expect(Link.looksLikePairCode('https://example.com'), isFalse);
    expect(Link.looksLikePairCode(null), isFalse);
  });

  testWidgets('home fits sideways too', (tester) async {
    tester.view.physicalSize = const Size(2424, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const HomeScreen(link: LinkState(LinkStatus.offline, pc: 'Gamer'))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon tiles fill their square and draw their art', (tester) async {
    await tester.pumpWidget(
      _app(
        Center(
          child: AppIcon(label: 'Files', art: Art.files, color: Cozy.sky, size: 76, onTap: () {}),
        ),
      ),
    );
    final art = find.descendant(of: find.byType(AppIcon), matching: find.byType(CustomPaint)).first;
    expect(tester.getSize(art).width, greaterThan(40)); // was 0 when the tile collapsed
  });

  testWidgets('downloads shows progress and stops from the phone', (tester) async {
    _phoneSize(tester);
    const state = {
      'on': true,
      'after': 'shutdown',
      'speed': 2097152,
      'saw': true,
      'quiet': 0,
      'items': [
        {'name': 'Nioh 3', 'app': 'Steam', 'done': 50, 'total': 100},
      ],
    };
    final sent = _fakeNative(
      tester,
      answers: {
        'lastDownload': jsonEncode({'t': 'dl', 's': state}),
      },
    );
    await tester.pumpWidget(_app(const DownloadsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Nioh 3'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.text('Stop Download mode'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(sent.last, {'t': 'do', 'what': 'dl.stop'});
  });

  testWidgets('downloads counts down before the PC shuts down', (tester) async {
    _phoneSize(tester);
    const state = {
      'on': false,
      'asking': true,
      'countdown': 95,
      'names': ['Nioh 3'],
      'items': [],
    };
    _fakeNative(
      tester,
      answers: {
        'lastDownload': jsonEncode({'t': 'dl', 's': state}),
      },
    );
    await tester.pumpWidget(_app(const DownloadsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1:35'), findsOneWidget);
    expect(find.text('Keep using'), findsOneWidget);
  });

  testWidgets('shutting down asks first', (tester) async {
    _phoneSize(tester);
    final sent = _fakeNative(tester);
    await tester.pumpWidget(_app(const PowerScreen()));
    await tester.tap(find.text('Shut down'));
    await tester.pumpAndSettle();
    expect(sent.where((m) => m['what'] == 'shutdown'), isEmpty);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(sent.where((m) => m['what'] == 'shutdown'), isEmpty);
  });

  testWidgets('music tells the PC only while it is open', (tester) async {
    _phoneSize(tester);
    final sent = _fakeNative(tester);
    await tester.pumpWidget(_app(const MusicScreen()));
    await tester.pump();
    expect(sent, anyElement(equals({'t': 'watch', 'what': 'music', 'on': true})));
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pump();
    expect(sent, anyElement(equals({'t': 'watch', 'what': 'music', 'on': false})));
  });

  testWidgets('terminal never opens while the PC does not allow it', (tester) async {
    _phoneSize(tester);
    final sent = _fakeNative(tester, answers: {'terminalAllowed': false});
    await tester.pumpWidget(_app(const TerminalScreen()));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.textContaining('Turn it on in Island'), findsOneWidget);
  });

  testWidgets('terminal needs the fingerprint even when allowed', (tester) async {
    _phoneSize(tester);
    final sent = _fakeNative(tester, answers: {'terminalAllowed': true, 'authenticate': false});
    await tester.pumpWidget(_app(const TerminalScreen()));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('terminal has Enter and it sends what was typed', (tester) async {
    _phoneSize(tester);
    final sent = _fakeNative(tester, answers: {'terminalAllowed': true, 'authenticate': true});
    await tester.pumpWidget(_app(const TerminalScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ls');
    await tester.tap(find.text('Enter'));
    await tester.pump();
    expect(sent, anyElement(equals({'t': 'term', 'text': 'ls\r'})));
  });

  testWidgets('alerts leads to Android settings until allowed', (tester) async {
    _phoneSize(tester);
    _fakeNative(tester, answers: {'alertsAccess': false, 'alertsOn': true});
    await tester.pumpWidget(_app(const AlertsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Allow in Android'), findsOneWidget);
  });
}
