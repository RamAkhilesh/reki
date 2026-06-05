// ─────────────────────────────────────────────────────────────
// lib/features/auth/data/auth_repository.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // ── Google Sign-In ─────────────────────────────────────────

  /// Returns false if the user dismissed the picker without signing in.
  Future<bool> signInWithGoogle() async {
    // Web falls back to the browser OAuth flow.
    if (kIsWeb) {
      return _client.auth.signInWithOAuth(OAuthProvider.google);
    }

    final googleSignIn = GoogleSignIn(
      // The web client ID is required so Google returns an ID token that
      // Supabase (which validates against the web OAuth client) can verify.
      serverClientId:
          const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      // iOS needs its own client ID; Android derives it from the registered
      // SHA-1 + package name and doesn't use this field.
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID')
          : null,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return false; // user cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Google sign-in returned no ID token');

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    return true;
  }
}
