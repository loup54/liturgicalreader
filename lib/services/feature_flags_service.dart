import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Centralised runtime-feature toggle service.
///
/// 1. Loads **compile-time flags** from the `FEATURE_FLAGS` Dart-define
///    (passed via `--dart-define-from-file=env.json` or individual
///    `--dart-define` values).
/// 2. Attempts to **override** those values by fetching the `feature_flags`
///    table from Supabase. Each row is expected to contain `{ key: string,
///    enabled: boolean }`.
/// 3. Falls back gracefully if Supabase is unavailable or the table is
///    undefined, enabling quick rollbacks through remote configuration while
///    keeping offline behaviour deterministic.
///
/// Usage:
/// ```dart
/// final flags = FeatureFlagsService();
/// await flags.initialize();
/// if (flags.isEnabled('audio_playback')) {
///   // render audio player
/// }
/// ```
class FeatureFlagsService {
  static final FeatureFlagsService _instance = FeatureFlagsService._internal();
  factory FeatureFlagsService() => _instance;
  FeatureFlagsService._internal();

  /// In-memory cache of flag values.
  final Map<String, bool> _flags = <String, bool>{};
  bool _isInitialized = false;

  /// Initialise the service – safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _loadCompileTimeFlags();
    await _tryLoadRemoteFlags();
    _isInitialized = true;
  }

  /// Returns `true` if the flag exists and is enabled, otherwise
  /// `defaultValue` (defaults to `false`).
  bool isEnabled(String key, {bool defaultValue = false}) {
    if (!_isInitialized) {
      debugPrint(
        'FeatureFlagsService used before initialization – defaulting to $defaultValue for "$key"',
      );
    }
    return _flags[key] ?? defaultValue;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _loadCompileTimeFlags() {
    const rawJson = String.fromEnvironment('FEATURE_FLAGS', defaultValue: '{}');
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((String k, dynamic v) {
          _flags[k] = v == true || v.toString().toLowerCase() == 'true';
        });
      }
    } catch (e) {
      debugPrint('FeatureFlagsService: Failed to parse compile-time flags – $e');
    }
  }

  Future<void> _tryLoadRemoteFlags() async {
    try {
      final SupabaseClient? client = await SupabaseService.getClient();
      if (client == null) return; // Supabase not configured

      final response = await client
          .from('feature_flags')
          .select('key, enabled')
          .execute();

      if (response.error == null && response.data is List) {
        for (final dynamic row in response.data as List<dynamic>) {
          final map = row as Map<String, dynamic>;
          final String key = map['key'] as String;
          final bool enabled = map['enabled'] as bool;
          _flags[key] = enabled;
        }
        debugPrint('FeatureFlagsService: Remote flags loaded – $_flags');
      } else {
        debugPrint('FeatureFlagsService: No feature_flags table or query error');
      }
    } catch (e) {
      debugPrint('FeatureFlagsService: Remote flag fetch failed – $e');
    }
  }
}
