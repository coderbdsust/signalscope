import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_card.dart';

/// Which dashboard cards are enabled. Persisted across app launches.
class SettingsStore extends ChangeNotifier {
  SharedPreferences? _prefs;
  final Map<DashboardCardId, bool> _enabled = {
    for (final id in DashboardCardId.values) id: true,
  };

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    for (final id in DashboardCardId.values) {
      _enabled[id] = _prefs!.getBool(id.prefKey) ?? true;
    }
  }

  bool isEnabled(DashboardCardId id) => _enabled[id] ?? true;

  Future<void> setEnabled(DashboardCardId id, bool value) async {
    if (isEnabled(id) == value) return;
    _enabled[id] = value;
    notifyListeners();
    await _prefs?.setBool(id.prefKey, value);
  }
}
