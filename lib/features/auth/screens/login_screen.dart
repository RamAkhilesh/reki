// ─────────────────────────────────────────────────────────────
// lib/features/auth/screens/login_screen.dart
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
      if (next.value is AuthStateAuthenticated) context.go(AppRoutes.home);
    });

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
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                  'Your personal media library',
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
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your password';
                              return null;
                            },
                          ),

                          // ── Forgot password ────────────────────────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showForgotPassword(context),
                              style: TextButton.styleFrom(
                                foregroundColor: inkDim,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: inkDim,
                                ),
                              ),
                            ),
                          ),

                          // ── Sign in button ─────────────────────────────
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
                                        'Sign In',
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

                          // ── Google sign-in ─────────────────────────────
                          _GoogleButton(
                            onTap: isLoading
                                ? null
                                : () => ref.read(authProvider.notifier).signInWithGoogle(),
                          ),
                          const SizedBox(height: 24),

                          // ── Register link ──────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: inkDim,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(AppRoutes.register),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                child: Text(
                                  'Sign Up',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: acc,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Guest access ───────────────────────────────
                          Center(
                            child: TextButton(
                              onPressed: () {
                                ref.read(guestModeProvider.notifier).state = true;
                                context.go(AppRoutes.home);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              ),
                              child: Text(
                                'Continue without an account',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: inkDimmer,
                                ),
                              ),
                            ),
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

  void _showForgotPassword(BuildContext context) {
    final ctrl = TextEditingController(text: _emailCtrl.text);

    void sendReset(BuildContext ctx) {
      ref.read(authProvider.notifier).resetPassword(ctrl.text.trim());
      Navigator.pop(ctx);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(100),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: GlassCard(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset password',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: P.ink(ctx),
                    letterSpacing: -0.02 * 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Enter your email and we'll send a reset link.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: P.inkDim(ctx),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  controller: ctrl,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => sendReset(ctx),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: P.glassStrong(ctx),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: P.border(ctx), width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: P.inkDim(ctx),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => sendReset(ctx),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: P.accent(ctx),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: P.accent(ctx).withAlpha(70),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Send link',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
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
