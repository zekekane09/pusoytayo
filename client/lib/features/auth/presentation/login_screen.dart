import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/auth/presentation/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${next.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFF1A0A3E),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final landscape = MediaQuery.of(context).orientation ==
                  Orientation.landscape;

              final controls = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UsernameLogin(isLoading: authState.isLoading),
                  const SizedBox(height: 16),
                  _LoginButtons(isLoading: authState.isLoading),
                  const SizedBox(height: 20),
                  _GuestButton(isLoading: authState.isLoading),
                  // Debug-only: tour the UI without Firebase or the backend.
                  if (kDebugMode) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .signInAsDemo(),
                      child: const Text(
                        'Explore Demo (no backend)',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'By continuing, you agree to our Terms of Service',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );

              if (landscape) {
                // Logo on the left, login controls on the right so everything
                // fits on a short landscape screen without scrolling.
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      const Expanded(child: Center(child: _LogoSection())),
                      const SizedBox(width: 32),
                      Expanded(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: controls,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LogoSection(),
                      const SizedBox(height: 48),
                      controls,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.style_rounded,
            size: 60,
            color: Colors.white,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),
        const SizedBox(height: 24),
        const Text(
          'PUSOY TAYO',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0),
        const SizedBox(height: 8),
        const Text(
          'Competitive 13-Card Pusoy',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
      ],
    );
  }
}

class _LoginButtons extends ConsumerWidget {
  final bool isLoading;

  const _LoginButtons({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(authControllerProvider.notifier);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _SocialLoginButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata_rounded,
            color: const Color(0xFFDB4437),
            onTap: isLoading ? null : () => controller.signInWithGoogle(),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 12),
            _SocialLoginButton(
              label: 'Continue with Apple',
              icon: Icons.apple_rounded,
              color: Colors.white,
              textColor: Colors.black,
              onTap: isLoading ? null : () => controller.signInWithApple(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.2, end: 0);
  }
}

class _GuestButton extends ConsumerWidget {
  final bool isLoading;

  const _GuestButton({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: isLoading
          ? null
          : () => ref.read(authControllerProvider.notifier).signInAsGuest(),
      icon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
      label: const Text(
        'Play as Guest',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
      ),
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _UsernameLogin extends ConsumerStatefulWidget {
  final bool isLoading;
  const _UsernameLogin({required this.isLoading});

  @override
  ConsumerState<_UsernameLogin> createState() => _UsernameLoginState();
}

class _UsernameLoginState extends ConsumerState<_UsernameLogin> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  final _name = TextEditingController();
  bool _signup = false;

  void _submit() {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.isEmpty || p.isEmpty) return;
    final ctrl = ref.read(authControllerProvider.notifier);
    if (_signup) {
      ctrl.registerWithUsername(u, p, _name.text.trim());
    } else {
      ctrl.signInWithUsername(u, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _user,
            enabled: !widget.isLoading,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Username',
              prefixIcon:
                  Icon(Icons.person_outline, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            enabled: !widget.isLoading,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Password',
              prefixIcon:
                  Icon(Icons.lock_outline, color: AppColors.textSecondary),
            ),
          ),
          if (_signup) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              enabled: !widget.isLoading,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Display name (optional)',
                prefixIcon:
                    Icon(Icons.badge_outlined, color: AppColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_signup ? 'Create account' : 'Login',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed:
                widget.isLoading ? null : () => setState(() => _signup = !_signup),
            child: Text(
              _signup
                  ? 'Have an account? Log in'
                  : 'New here? Sign up — 100 free coins',
              style: const TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
