import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:island_link/link.dart';
import 'package:island_link/screens/home.dart';
import 'package:island_link/screens/welcome.dart';
import 'package:island_link/theme.dart';
import 'package:island_link/widgets/app_icon.dart';

Widget _app(Widget child) => MaterialApp(theme: Cozy.theme(), home: child);

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
}
