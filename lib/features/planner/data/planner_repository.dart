import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models.dart';

/// Persists the whole plan as one JSON document in local storage.
class PlannerRepository {
  PlannerRepository(this._prefs);

  final SharedPreferences _prefs;

  List<Project> load() {
    final raw = _prefs.getString(AppConstants.storageKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((p) => Project.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const []; // corrupt data: start fresh rather than crash
    }
  }

  Future<void> save(List<Project> projects) => _prefs.setString(
    AppConstants.storageKey,
    jsonEncode(projects.map((p) => p.toJson()).toList()),
  );
}
