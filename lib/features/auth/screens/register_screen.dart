// ─────────────────────────────────────────────────────────────
// lib/features/auth/screens/register_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (mounted) {
      final authState = ref.read(authProvider).value;
      if (authState is AuthStateUnauthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check your email to confirm your account, then sign in.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.value is AuthStateLoading;
    final errorMsg = authState.value is AuthStateError
        ? (authState.value as AuthStateError).message
        : null;

    final inkDim = P.inkDim(context);
    final inkDimmer = P.inkDimmer(context);
    final acc = P.accent(context);
    final acc2 = P.accent2(context);
    final acc3 = P.accent3(context);

    return Scaffold(
      backgroundColor: P.bg(context),
      body: Stack(
        children: [
          const Positioned.fill(child: PrismBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Back button ────────────────────────────────
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GlassButton(
                              onTap: () => context.pop(),
                              size: 38,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: P.ink(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── App identity ───────────────────────────────
                          Center(
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (r) => LinearGradient(
                                    colors: [acc, acc2, acc3],
                                    stops: const [0, 0.5, 1],
                                  ).createShader(r),
                                  child: Text(
                                    'reki',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.04 * 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create your account',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: inkDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Error banner ───────────────────────────────
                          if (errorMsg != null) ...[
                            AuthErrorBanner(
                              message: errorMsg,
                              onDismiss: () =>
                                  ref.read(authProvider.notifier).clearError(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Fields ─────────────────────────────────────
                          AuthTextField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_passwordFocus),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            obscure: true,
                            focusNode: _passwordFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_confirmFocus),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter a password';
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _confirmCtrl,
                            label: 'Confirm password',
                            obscure: true,
                            focusNode: _confirmFocus,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passwordCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Create account button ──────────────────────
                          GestureDetector(
                            onTap: isLoading ? null : _submit,
                            child: AnimatedOpacity(
                              opacity: isLoading ? 0.7 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: acc,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: acc.withAlpha(70),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Or divider ─────────────────────────────────
                          Row(
                            children: [
                              Expanded(child: Container(height: 0.7, color: inkDimmer)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: inkDimmer,
                                  ),
                                ),
                              ),
                              Expanded(child: Container(height: 0.7, color: inkDimmer)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Google sign-up ─────────────────────────────
                          _GoogleButton(
                            onTap: isLoading
                                ? null
                                : () => ref.read(authProvider.notifier).signInWithGoogle(),
                          ),
                          const SizedBox(height: 24),

                          // ── Login link ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: inkDim,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                child: Text(
                                  'Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: acc,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In button ──────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _GoogleButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    final glassStrong = P.glassStrong(context);
    final border = P.border(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: glassStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                'G',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4285F4),
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
