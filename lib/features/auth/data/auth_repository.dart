// ─────────────────────────────────────────────────────────────
// lib/features/auth/data/auth_repository.dart
// ─────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  // ── Streams ────────────────────────────────────────────────

  /// Emits the current [Session] whenever auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Current session (null if signed out).
  Session? get currentSession => _client.auth.currentSession;

  /// Current user (null if signed out).
  User? get currentUser => _client.auth.currentUser;

  // ── Email + Password ───────────────────────────────────────

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Password reset ─────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
