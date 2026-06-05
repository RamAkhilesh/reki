// ─────────────────────────────────────────────────────────────
// lib/features/auth/providers/auth_providers.dart
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/auth_repository.dart';

// ── Repository provider ────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(sb.Supabase.instance.client);
});

// ── Auth state ─────────────────────────────────────────────────

/// Sealed state representing all possible auth states.
sealed class AuthState {
  const AuthState();
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateAuthenticated extends AuthState {
  final sb.User user;
  const AuthStateAuthenticated(this.user);
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}

// ── Auth notifier ──────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  late AuthRepository _repo;
  StreamSubscription<sb.AuthState>? _sub;

  @override
  Future<AuthState> build() async {
    _repo = ref.read(authRepositoryProvider);

    // Cancel previous subscription on rebuild
    _sub?.cancel();
    _sub = _repo.authStateChanges.listen((authState) {
      final session = authState.session;
      if (session != null) {
        state = AsyncData(AuthStateAuthenticated(session.user));
      } else {
        state = const AsyncData(AuthStateUnauthenticated());
      }
    });

    ref.onDispose(() => _sub?.cancel());

    // Resolve initial state
    final session = _repo.currentSession;
    if (session != null) {
      return AuthStateAuthenticated(session.user);
    }
    return const AuthStateUnauthenticated();
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncData(AuthStateLoading());
    try {
      final response = await _repo.signUpWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = AsyncData(AuthStateAuthenticated(response.user!));
      } else {
        // Supabase sends confirmation email — user not yet active
        state = const AsyncData(AuthStateUnauthenticated());
      }
    } on sb.AuthException catch (e) {
      state = AsyncData(AuthStateError(e.message));
    } catch (e) {
      state = AsyncData(AuthStateError('Unexpected error: $e'));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncData(AuthStateLoading());
    try {
      final response = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = AsyncData(AuthStateAuthenticated(response.user!));
      } else {
        state = const AsyncData(AuthStateError('Sign in failed.'));
      }
    } on sb.AuthException catch (e) {
      state = AsyncData(AuthStateError(e.message));
    } catch (e) {
      state = AsyncData(AuthStateError('Unexpected error: $e'));
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(AuthStateUnauthenticated());
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncData(AuthStateLoading());
    try {
      final didSignIn = await _repo.signInWithGoogle();
      if (!didSignIn) {
        // User dismissed the picker — not an error
        state = const AsyncData(AuthStateUnauthenticated());
      }
      // On success the stream listener in build() updates state automatically
    } on sb.AuthException catch (e) {
      state = AsyncData(AuthStateError(e.message));
    } catch (e) {
      state = AsyncData(AuthStateError('Google sign-in failed'));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _repo.sendPasswordResetEmail(email);
    } on sb.AuthException catch (e) {
      state = AsyncData(AuthStateError(e.message));
    }
  }

  // TODO: wire up a Supabase Edge Function to delete the user record server-side
  Future<bool> deleteAccount() async {
    try {
      await _repo.signOut();
      state = const AsyncData(AuthStateUnauthenticated());
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearError() {
    if (state.value is AuthStateError) {
      state = const AsyncData(AuthStateUnauthenticated());
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Convenience provider — true when user is signed in.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.value is AuthStateAuthenticated;
});
