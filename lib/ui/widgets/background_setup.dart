import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/system.dart';
import '../../core/theme.dart';
import 'common.dart';

const _kAsked = 'background_setup_asked_v1';

/// Shown once after sign-in if Android may throttle the app: without this,
/// new-company alerts can arrive only when the app is opened.
Future<void> offerBackgroundSetupOnce(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_kAsked) ?? false) return;
  final ok = await SystemBridge.isIgnoringBatteryOptimizations();
  final oem = SystemBridge.isAggressiveOem(await SystemBridge.manufacturer());
  if (ok && !oem) return;
  await p.setBool(_kAsked, true);
  if (context.mounted) await showBackgroundSetupSheet(context);
}

Future<void> showBackgroundSetupSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => const _BackgroundSetupSheet(),
  );
}

class _BackgroundSetupSheet extends StatefulWidget {
  const _BackgroundSetupSheet();

  @override
  State<_BackgroundSetupSheet> createState() => _BackgroundSetupSheetState();
}

class _BackgroundSetupSheetState extends State<_BackgroundSetupSheet> with WidgetsBindingObserver {
  bool _battery = false;
  bool _oem = false;
  String _brand = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when the student comes back from the system settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final b = await SystemBridge.isIgnoringBatteryOptimizations();
    final m = await SystemBridge.manufacturer();
    if (mounted) {
      setState(() {
        _battery = b;
        _brand = m;
        _oem = SystemBridge.isAggressiveOem(m);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconBadge(Icons.notifications_active_rounded, size: 60, gradient: AppColors.brandGradient),
          ),
          const SizedBox(height: 14),
          Text('Never miss a company', textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
            'TnP Student checks for new companies every 15 minutes, even when the app is closed. '
            'Android may pause it to save battery — allow it once so alerts arrive on time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          _Step(
            index: 1,
            title: 'Allow background activity',
            subtitle: 'Choose "Allow" when Android asks',
            done: _battery,
            onTap: () => SystemBridge.requestIgnoreBatteryOptimizations(),
          ),
          if (_oem) ...[
            const SizedBox(height: 10),
            _Step(
              index: 2,
              title: 'Turn on Autostart',
              subtitle: 'Required on ${_brand.isEmpty ? 'your phone' : _brand} — find TnP Student and enable it',
              done: false,
              optionalDone: true,
              onTap: () => SystemBridge.openAutostartSettings(),
            ),
          ],
          const SizedBox(height: 20),
          GradientButton(
            label: _battery ? 'Done' : 'Maybe later',
            icon: _battery ? Icons.check_rounded : null,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
    this.optionalDone = false,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool done;

  /// For steps we can't verify (OEM autostart), show an arrow instead of a tick.
  final bool optionalDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = done ? AppColors.success : AppColors.crimson;
    return AppCard(
      onTap: done ? null : onTap,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: done
                ? Icon(Icons.check_rounded, color: c, size: 20)
                : Text(
                    '$index',
                    style: TextStyle(color: c, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  done ? 'Done' : subtitle,
                  style: context.text.bodySmall?.copyWith(color: done ? AppColors.success : context.palette.muted),
                ),
              ],
            ),
          ),
          if (!done)
            Icon(optionalDone ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, color: context.palette.muted),
        ],
      ),
    );
  }
}
