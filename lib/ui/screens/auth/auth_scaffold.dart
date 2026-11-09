import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme.dart';
import '../../widgets/common.dart';

/// Animated navy backdrop with drifting brand-coloured orbs.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.child});
  final Widget? child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1C2036), AppColors.navyInk],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            final size = MediaQuery.sizeOf(context);
            return Stack(
              children: [
                _orb(
                  left: size.width * 0.55 + math.cos(t) * 40,
                  top: -80 + math.sin(t) * 30,
                  size: 300,
                  color: AppColors.crimson,
                ),
                _orb(
                  left: -120 + math.sin(t) * 40,
                  top: size.height * 0.22 + math.cos(t) * 40,
                  size: 280,
                  color: AppColors.coral,
                ),
                _orb(
                  left: size.width * 0.3 + math.cos(t + 1) * 50,
                  top: size.height * 0.72 + math.sin(t + 1) * 30,
                  size: 260,
                  color: AppColors.indigo,
                ),
              ],
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _orb({required double left, required double top, required double size, required Color color}) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)]),
          ),
        ),
      ),
    );
  }
}

/// Layout for every pre-login screen: brand header + floating form card.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navyInk,
        resizeToAvoidBottomInset: true,
        body: AuroraBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showBack)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 8),
                      const Center(
                            child: Hero(tag: 'brand-logo', child: BrandLogo(size: 76)),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 600.ms),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.text.headlineMedium?.copyWith(color: Colors.white),
                      ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.45,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 28),
                      Theme(
                            data: AppTheme.light(),
                            child: Builder(
                              builder: (context) => Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                      spreadRadius: -10,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 260.ms, duration: 500.ms)
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                      if (footer != null) ...[
                        const SizedBox(height: 20),
                        footer!.animate().fadeIn(delay: 400.ms, duration: 400.ms),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline banner for success / error feedback inside auth forms.
class FormBanner extends StatelessWidget {
  const FormBanner({super.key, required this.message, this.success = false});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final c = success ? AppColors.success : AppColors.danger;
    final box = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
    return success ? box : box.shakeX(hz: 4, amount: 3, duration: 350.ms);
  }
}
