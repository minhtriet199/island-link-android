// Dart side of the link. The connection itself lives in native code (LinkService.kt)
// so it keeps running when the app is closed; this file just talks to it.
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

  /// Current state first, then every change while the app is open.
  static final Stream<LinkState> states = _events.receiveBroadcastStream().map(
    (e) => LinkState.fromMap(e as Map<Object?, Object?>),
  );

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
