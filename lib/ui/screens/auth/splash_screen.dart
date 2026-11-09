import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../state/auth.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // Give the intro animation a moment, then restore the session.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) ref.read(authProvider.notifier).bootstrap();
    });
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await ref.read(authProvider.notifier).bootstrap();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final offline = auth.status == AuthStatus.unknown && auth.message != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navyInk,
        body: AuroraBackground(
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const Hero(tag: 'brand-logo', child: BrandLogo(size: 108))
                    .animate()
                    .scale(begin: const Offset(0.6, 0.6), duration: 800.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 28),
                Text(
                  'Training & Placement',
                  style: context.text.headlineSmall?.copyWith(color: Colors.white),
                ).animate().fadeIn(delay: 250.ms, duration: 500.ms).slideY(begin: 0.4, end: 0),
                const SizedBox(height: 6),
                Text(
                  'NSUT Student Portal',
                  style: context.text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                const Spacer(flex: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: offline
                      ? Padding(
                          key: const ValueKey('offline'),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(height: 10),
                              Text(
                                auth.message!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 200,
                                child: GradientButton(
                                  label: 'Retry',
                                  icon: Icons.refresh_rounded,
                                  loading: _retrying,
                                  onPressed: _retry,
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref.read(authProvider.notifier).logout(),
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                child: const Text('Sign in with another account'),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('loading'),
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              color: AppColors.coral,
                            ),
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
