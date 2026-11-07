import 'package:flutter/services.dart';

/// MAC prefix (OUI) -> vendor name, loaded from assets/oui.csv.
/// Generate the asset with tool/generate_oui.py.
class OuiLookup {
  OuiLookup._();
  static final OuiLookup instance = OuiLookup._();

  Map<String, String>? _db;

  Future<void> ensureLoaded() async {
    if (_db != null) return;
    final map = <String, String>{};
    try {
      final text = await rootBundle.loadString('assets/oui.csv');
      for (final line in text.split('\n')) {
        if (line.length < 8 || line.startsWith('#')) continue;
        final i = line.indexOf(',');
        if (i != 6) continue;
        map[line.substring(0, 6).toUpperCase()] = line.substring(7).trim();
      }
    } catch (_) {
      // Asset missing -> vendor stays unknown, everything else still works.
    }
    _db = map;
  }

  /// [mac] must be normalized "AA:BB:CC:DD:EE:FF".
  String? vendorOf(String mac) {
    final db = _db;
    if (db == null || mac.length < 8) return null;
    return db[mac.substring(0, 8).replaceAll(':', '')];
  }
}
