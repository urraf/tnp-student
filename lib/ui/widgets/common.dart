import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';

// ----------------------------------------------------------------- Toasts --

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, info }

void showToast(String message, {ToastType type = ToastType.info}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  final (icon, color) = switch (type) {
    ToastType.success => (Icons.check_circle_rounded, AppColors.success),
    ToastType.error => (Icons.error_rounded, AppColors.danger),
    ToastType.info => (Icons.info_rounded, AppColors.info),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: Duration(seconds: type == ToastType.error ? 5 : 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

void toastError(Object e) => showToast(ApiException.from(e).message, type: ToastType.error);

// -------------------------------------------------------------- Animation --

extension EntranceX on Widget {
  /// Staggered fade + rise used across lists.
  Widget entrance(int index, {int baseMs = 40}) => animate()
      .fadeIn(duration: 380.ms, delay: (baseMs * (index.clamp(0, 10))).ms, curve: Curves.easeOut)
      .slideY(
        begin: 0.12,
        end: 0,
        duration: 420.ms,
        delay: (baseMs * (index.clamp(0, 10))).ms,
        curve: Curves.easeOutCubic,
      );
}

/// Shrinks slightly while pressed — gives every tappable surface a tactile feel.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ------------------------------------------------------------------ Cards --

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color,
    this.gradient,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: gradient == null ? Border.all(color: borderColor ?? p.border) : null,
        boxShadow: shadow
            ? [BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -8)]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

// ---------------------------------------------------------------- Buttons --

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 54,
    this.gradient = AppColors.brandGradient,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final Gradient gradient;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || loading ? 1 : 0.45,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.crimson.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: loading
                ? const SizedBox(
                    key: ValueKey('l'),
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('c'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10)],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded square with a tinted icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = AppColors.crimson, this.size = 40, this.gradient});

  final IconData icon;
  final Color color;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient == null ? color.withValues(alpha: context.isDark ? 0.2 : 0.1) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: gradient == null ? color : Colors.white),
    );
  }
}

// ---------------------------------------------------------------- Avatars --

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 48, this.radius});

  final String name;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.avatarGradient(name),
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36, letterSpacing: 0.5),
      ),
    );
  }
}

/// Company logo from the S3 bucket the web uses, falling back to initials.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = InitialsAvatar(name: name.isEmpty ? 'N' : name, size: size);
    if (name.trim().isEmpty) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: AppConfig.companyLogoUrl(name),
        memCacheWidth: (size * dpr).round(),
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) => Container(color: context.palette.subtle),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

// ------------------------------------------------------------------ Pills --

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon, this.filled = false, this.dense = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: context.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: filled ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.white : c,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.dense = false});
  final String status;
  final bool dense;

  static Color colorFor(String s) {
    final v = s.toLowerCase();
    if (v.contains('accept') ||
        v.contains('select') ||
        v.contains('open') ||
        v.contains('resolved') ||
        v.contains('placed') ||
        v.contains('active') ||
        v.contains('ongoing')) {
      return AppColors.success;
    }
    if (v.contains('reject') || v.contains('end') || v.contains('closed') || v.contains('not')) {
      return AppColors.danger;
    }
    if (v.contains('pend') || v.contains('review') || v.contains('applied') || v.contains('shortlist')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) => Pill(status, color: colorFor(status), dense: dense);
}

// --------------------------------------------------------------- Sections --

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing, this.icon});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[IconBadge(icon!, size: 34), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, size: 36, color: AppColors.indigo),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelMedium?.copyWith(color: context.palette.muted)),
                const SizedBox(height: 2),
                SelectableText(
                  value.isEmpty ? '—' : value,
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.palette.muted),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
  }
}

// --------------------------------------------------------- Empty / Error --

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_rounded, this.action});

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.coral.withValues(alpha: 0.18), AppColors.crimson.withValues(alpha: 0.08)],
                    ),
                  ),
                  child: Icon(icon, size: 42, color: AppColors.crimson),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -3, end: 3, duration: 1800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: context.text.bodyMedium?.copyWith(color: context.palette.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.96, 0.96)),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = ApiException.from(error).message;
    final offline = msg.toLowerCase().contains('internet');
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
      title: offline ? 'You\'re offline' : 'Couldn\'t load this',
      subtitle: msg,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
    );
  }
}

// --------------------------------------------------------------- Skeleton --

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1C2134) : const Color(0xFFE9EBF2),
      highlightColor: dark ? const Color(0xFF2A3048) : const Color(0xFFF8F9FC),
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
  );
}

/// Generic list-card skeleton.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.shrinkWrap = false,
  });
  final int count;
  final EdgeInsets padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 52, height: 52, radius: 16),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 180, height: 16),
                    SizedBox(height: 10),
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 200, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Async view --

/// Renders an [AsyncValue] with skeleton/error/data states and smooth swaps.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.loading, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    final key = ValueKey(
      value.hasValue
          ? 'd'
          : value.hasError
          ? 'e'
          : 'l',
    );
    if (value.hasValue) {
      child = data(value.requireValue);
    } else if (value.hasError) {
      child = ErrorState(error: value.error!, onRetry: onRetry);
    } else {
      child = loading ?? const SkeletonList();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

// ---------------------------------------------------------------- Dialogs --

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  String? requiredPhrase,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final ok = requiredPhrase == null || controller.text.trim() == requiredPhrase;
        return AlertDialog(
          icon: Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
            color: destructive ? AppColors.danger : AppColors.info,
            size: 32,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (requiredPhrase != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'Type $requiredPhrase to confirm'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: ctx.palette.muted),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: ok ? () => Navigator.pop(ctx, true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? AppColors.danger : AppColors.crimson,
                minimumSize: const Size(100, 44),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result ?? false;
}

/// Brand logo, used on splash / auth / drawer.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}
