import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseClient? _client;
  static bool _isInitialized = false;
  static String? _initializationError;

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Environment variables with fallback values
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Get client with initialization check
  static Future<SupabaseClient?> getClient() async {
    if (_client != null && _isInitialized) {
      return _client;
    }

    try {
      await _initializeSupabase();
      return _client;
    } catch (e) {
      debugPrint('Supabase client unavailable: $e');
      return null;
    }
  }

  // Initialize Supabase with comprehensive error handling
  static Future<void> _initializeSupabase() async {
    if (_isInitialized && _client != null) {
      return; // Already initialized
    }

    try {
      // Validate environment variables
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        _initializationError =
            'Supabase configuration missing. Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.';
        debugPrint(_initializationError);
        _isInitialized = true; // Mark as initialized but with error
        return;
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;
      _initializationError = null;

      debugPrint('Supabase initialized successfully');

      // Test database connection
      await _testDatabaseConnection();
    } catch (e) {
      _initializationError = 'Failed to initialize Supabase: $e';
      debugPrint(_initializationError);
      _isInitialized = true; // Mark as initialized but with error
      _client = null;
    }
  }

  // Test database connection and ensure critical tables exist
  static Future<void> _testDatabaseConnection() async {
    if (_client == null) return;

    try {
      // Test basic connection with a simple query
      final response =
          await _client!.from('liturgical_days').select('id').limit(1);

      debugPrint('Database connection test successful');
    } catch (e) {
      debugPrint('Database connection test failed: $e');
      // Don't throw error - let app continue with offline mode
    }
  }

  // Check if Supabase is available and properly configured
  static bool get isAvailable =>
      _client != null && _initializationError == null;

  // Get initialization status
  static bool get isInitialized => _isInitialized;

  // Get initialization error if any
  static String? get initializationError => _initializationError;

  // Initialize method for external use
  static Future<void> initialize() async {
    await _initializeSupabase();
  }
}
