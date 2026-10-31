// Dart side of the link. The connection itself lives in native code (LinkService.kt)
// so it keeps running when the app is closed; this file just talks to it.
import 'dart:convert';

import 'package:flutter/services.dart';

enum LinkStatus { unpaired, connecting, connected, offline }

class LinkState {
  const LinkState(this.status, {this.pc, this.error});
  final LinkStatus status;
  final String? pc;
  final String? error;

  bool get paired => status != LinkStatus.unpaired;

  factory LinkState.fromMap(Map<Object?, Object?> m) => LinkState(
    LinkStatus.values.asNameMap()[m['status']] ?? LinkStatus.unpaired,
    pc: m['pc'] as String?,
    error: m['error'] as String?,
  );
}

/// Thrown when pairing fails, with a message meant for the user.
class PairException implements Exception {
  const PairException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class Link {
  static const _methods = MethodChannel('island_link/link');
  static const _events = EventChannel('island_link/status');
  static const _msgs = EventChannel('island_link/msg');

  /// Current state first, then every change while the app is open.
  static final Stream<LinkState> states = _events.receiveBroadcastStream().map((e) {
    return last = LinkState.fromMap(e as Map<Object?, Object?>);
  });

  /// The newest state, for screens that start listening later.
  static LinkState last = const LinkState(LinkStatus.connecting);

  /// What the PC sends while the app is open: `{"t": "dl" | "music" | "levels" | "clip" | "term" | ...}`.
  static final Stream<Map<String, dynamic>> messages = _msgs.receiveBroadcastStream().map(
    (e) => jsonDecode(e as String) as Map<String, dynamic>,
  );

  /// Messages of one kind.
  static Stream<Map<String, dynamic>> on(String kind) => messages.where((m) => m['t'] == kind);

  /// Sends one message to the PC. False when the link is down right now.
  static Future<bool> send(Map<String, Object?> msg) async =>
      await _methods.invokeMethod<bool>('send', jsonEncode(msg)) ?? false;

  /// Asks the PC to do one of the actions it allows.
  static Future<bool> act(String what, [String? arg]) => send({'t': 'do', 'what': what, 'arg': ?arg});

  /// Tells the PC a screen that needs live data opened or closed.
  static Future<bool> watch(String what, bool on) => send({'t': 'watch', 'what': what, 'on': on});

  /// The latest Download mode state, if the PC has sent one since the link started.
  static Future<Map<String, dynamic>?> lastDownload() async {
    final s = await _methods.invokeMethod<String>('lastDownload');
    return s == null ? null : (jsonDecode(s) as Map<String, dynamic>)['s'] as Map<String, dynamic>;
  }

  static Future<bool> terminalAllowed() async => await _methods.invokeMethod<bool>('terminalAllowed') ?? false;

  /// Has Android been told this app may read notifications?
  static Future<bool> alertsAccess() async => await _methods.invokeMethod<bool>('alertsAccess') ?? false;
  static Future<void> openAlertsAccess() => _methods.invokeMethod('openAlertsAccess');
  static Future<bool> alertsOn() async => await _methods.invokeMethod<bool>('alertsOn') ?? true;
  static Future<void> setAlertsOn(bool on) => _methods.invokeMethod('setAlertsOn', on);

  /// Fingerprint or screen lock. False if cancelled or impossible.
  static Future<bool> authenticate(String reason) async =>
      await _methods.invokeMethod<bool>('authenticate', reason) ?? false;

  /// Pairs with the PC from a scanned `islandlink://pair?...` code. Returns the PC's name.
  static Future<String> pair(String code) async {
    try {
      return (await _methods.invokeMethod<String>('pair', code))!;
    } on PlatformException catch (e) {
      throw PairException(e.message ?? 'Pairing failed.');
    }
  }

  /// Makes sure the background link runs (no-op when not paired).
  static Future<void> start() => _methods.invokeMethod('start');

  /// Opens the system file picker; whatever is picked is sent to the PC in the background
  /// (progress shows as a notification). Returns how many files were picked.
  static Future<int> pickAndSendFiles() async => await _methods.invokeMethod<int>('pickFiles') ?? 0;

  /// Forgets the PC on this phone and stops the link.
  static Future<void> forget() => _methods.invokeMethod('forget');

  static bool looksLikePairCode(String? s) => s != null && s.startsWith('islandlink://pair?');
}
