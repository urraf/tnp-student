import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/alerts.dart';
import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import '../home_shell.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(studentProvider);
    final mode = ref.watch(themeModeProvider);

    final tiles = <(IconData, String, String, Color, VoidCallback)>[
      (
        Icons.folder_copy_rounded,
        'Forms & Docs',
        'Undertakings, uploads',
        AppColors.indigo,
        () => context.push('/more/forms'),
      ),
      (Icons.verified_rounded, 'NOC', 'Request & download', AppColors.success, () => context.push('/more/forms?tab=1')),
      (Icons.rate_review_rounded, 'Feedback', 'Ask a query', AppColors.crimson, () => context.push('/more/feedback')),
      (
        Icons.forum_rounded,
        'My Feedbacks',
        'Replies from TnP',
        AppColors.warning,
        () => context.push('/more/my-feedbacks'),
      ),
      (
        Icons.policy_rounded,
        'Placement Policy',
        'TnP guidelines',
        AppColors.info,
        () => openLink(context, AppConfig.placementPolicyUrl, title: 'Placement Policy'),
      ),
      (
        Icons.support_agent_rounded,
        'Contact',
        'TnP office',
        const Color(0xFF0D9488),
        () => context.push('/more/contact'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 0, 0, navBarInset(context)),
          children: [
            const TabHeader(title: 'More', subtitle: 'Documents, support and settings'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                onTap: () => context.go('/profile'),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    InitialsAvatar(name: s?.name ?? 'S', size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s?.name ?? '',
                            style: context.text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            s?.email ?? '',
                            style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.palette.muted),
                  ],
                ),
              ).entrance(0),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: tiles.length,
                itemBuilder: (_, i) {
                  final t = tiles[i];
                  return AppCard(
                    onTap: t.$5,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(t.$1, color: t.$4, size: 42),
                        const Spacer(),
                        Text(t.$2, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          t.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                        ),
                      ],
                    ),
                  ).entrance(i + 1);
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Notifications', icon: Icons.notifications_active_rounded),
                  const _AlertsCard(),
                  const SizedBox(height: 24),
                  const SectionHeader('Appearance', icon: Icons.palette_rounded),
                  AppCard(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        for (final (m, label, icon) in [
                          (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                          (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                          (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                        ])
                          Expanded(
                            child: Pressable(
                              onTap: () => ref.read(themeModeProvider.notifier).set(m),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: mode == m ? AppColors.brandGradient : null,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Icon(icon, color: mode == m ? Colors.white : context.palette.muted),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: mode == m ? Colors.white : context.palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader('About', icon: Icons.info_rounded),
                  AppCard(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language_rounded),
                          title: const Text('Open web portal', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                          onTap: () => openLink(context, 'https://student.tnpnsut.in'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_reset_rounded),
                          title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('We\'ll email you a reset link'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final email = s?.email ?? '';
                            final ok = await confirmDialog(
                              context,
                              title: 'Reset password?',
                              message: 'A reset link will be sent to $email.',
                              confirmLabel: 'Send link',
                            );
                            if (!ok) return;
                            try {
                              await ref.read(repositoryProvider).forgotPassword(email);
                              showToast('Reset link sent to $email', type: ToastType.success);
                            } catch (e) {
                              toastError(e);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Sign out?',
                        message: 'You\'ll need to sign in again to use the app.',
                        confirmLabel: 'Sign out',
                        destructive: true,
                      );
                      if (ok) ref.read(authProvider.notifier).logout();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '${AppConfig.appName} · v1.0.0',
                      style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle + controls for background "new company" alerts.
class _AlertsCard extends StatefulWidget {
  const _AlertsCard();

  @override
  State<_AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends State<_AlertsCard> {
  bool? _enabled;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    Alerts.isEnabled().then((v) => mounted ? setState(() => _enabled = v) : null);
  }

  Future<void> _toggle(bool on) async {
    setState(() => _enabled = on);
    try {
      if (on) {
        final granted = await Alerts.enable();
        if (!granted) {
          showToast('Notifications are blocked. Allow them for TnP Student in system settings.', type: ToastType.error);
        } else {
          showToast('You\'ll be notified about new companies and notices', type: ToastType.success);
        }
      } else {
        await Alerts.disable();
        showToast('Alerts turned off');
      }
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      final n = await Alerts.checkNow();
      showToast(n.alertsSummary, type: n == 0 ? ToastType.info : ToastType.success);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Many Android brands kill background work unless the app is exempt
  /// from battery optimisation.
  Future<void> _batterySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.tnpnsut.student',
      ).launch();
    } catch (_) {
      try {
        await const AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS').launch();
      } catch (e) {
        showToast('Open Settings → Apps → TnP Student → Battery → Unrestricted', type: ToastType.info);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _enabled ?? true;
    return AppCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          SwitchListTile(
            value: on,
            onChanged: _enabled == null ? null : _toggle,
            secondary: const Icon(Icons.campaign_rounded),
            title: const Text('New company & notice alerts', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Checks about every 15 min, even when the app is closed'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: on
                ? Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('Check now', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: _checking
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _checking ? null : _checkNow,
                      ),
                      if (defaultTargetPlatform == TargetPlatform.android)
                        ListTile(
                          leading: const Icon(Icons.battery_charging_full_rounded),
                          title: const Text('Allow background checks', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Recommended on Xiaomi, Oppo, Vivo, Realme, OnePlus'),
                          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                          onTap: _batterySettings,
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
