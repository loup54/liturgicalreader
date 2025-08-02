import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _initializeAuthState();
  }

  bool _isAuthenticatedCache = false;

  void _initializeAuthState() async {
    _isAuthenticatedCache = await isAuthenticated;
  }

  // Synchronous getter for cached authentication state
  bool get isAuthenticatedSync => _isAuthenticatedCache;

  // Get current user with null safety
  Future<User?> get currentUser async {
    final client = await SupabaseService.getClient();
    return client?.auth.currentUser;
  }

  // Check if user is authenticated
  Future<bool> get isAuthenticated async {
    final user = await currentUser;
    final authState = user != null;
    _isAuthenticatedCache = authState; // Update cache
    return authState;
  }

  // Sign in with email and password
  Future<AuthResponse?> signIn(String email, String password) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        debugPrint('Cannot sign in: Supabase client unavailable');
        return null;
      }

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Update cached auth state
      _isAuthenticatedCache = response.user != null;

      return response;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<AuthResponse?> signUp(String email, String password) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        debugPrint('Cannot sign up: Supabase client unavailable');
        return null;
      }

      final response = await client.auth.signUp(
        email: email,
        password: password,
      );

      // Update cached auth state
      _isAuthenticatedCache = response.user != null;

      return response;
    } catch (e) {
      debugPrint('Sign up failed: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        debugPrint('Cannot sign out: Supabase client unavailable');
        return;
      }

      await client.auth.signOut();

      // Update cached auth state
      _isAuthenticatedCache = false;
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  // Listen to auth state changes
  Stream<AuthState> authStateChanges() async* {
    final client = await SupabaseService.getClient();
    if (client == null) {
      return;
    }
    yield* client.auth.onAuthStateChange;
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final client = await SupabaseService.getClient();
      final user = await currentUser;
      if (client == null || user == null) {
        return null;
      }

      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Failed to get user profile: $e');
      return null;
    }
  }

  // Check if authentication is available
  bool get isAuthAvailable => SupabaseService.isAvailable;
}
