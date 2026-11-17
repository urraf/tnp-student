import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../core/updater.dart';
import 'common.dart';

const _kSnoozedVersion = 'update_snoozed_version';
const _kSnoozedAt = 'update_snoozed_at_ms';

/// Checks for an update and shows the sheet unless the student snoozed this
/// version in the last 3 days. Safe to call on every app start.
Future<void> promptForUpdateIfAny(BuildContext context) async {
  final update = await Updater.check();
  if (update == null || !context.mounted) return;
  final p = await SharedPreferences.getInstance();
  final snoozedAt = p.getInt(_kSnoozedAt) ?? 0;
  final snoozed =
      p.getString(_kSnoozedVersion) == update.version &&
      DateTime.now().millisecondsSinceEpoch - snoozedAt < const Duration(days: 3).inMilliseconds;
  if (snoozed || !context.mounted) return;
  await showUpdateSheet(context, update);
}

/// Manual "Check for updates" from More.
Future<void> checkForUpdatesManually(BuildContext context) async {
  final update = await Updater.check();
  if (!context.mounted) return;
  if (update == null) {
    showToast('You\'re on the latest version (${await Updater.currentVersion()})', type: ToastType.success);
    return;
  }
  await showUpdateSheet(context, update);
}

Future<void> showUpdateSheet(BuildContext context, AppUpdate update) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => _UpdateSheet(update: update),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.update});
  final AppUpdate update;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

enum _Stage { idle, downloading, ready }

class _UpdateSheetState extends State<_UpdateSheet> {
  final _cancel = CancelToken();
  _Stage _stage = _Stage.idle;
  double _progress = 0;
  String? _path;
  String? _current;

  @override
  void initState() {
    super.initState();
    Updater.currentVersion().then((v) => mounted ? setState(() => _current = v) : null);
  }

  @override
  void dispose() {
    if (_stage == _Stage.downloading) _cancel.cancel();
    super.dispose();
  }

  Future<void> _later() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSnoozedVersion, widget.update.version);
    await p.setInt(_kSnoozedAt, DateTime.now().millisecondsSinceEpoch);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _download() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
    });
    try {
      final path = await Updater.download(
        widget.update,
        cancel: _cancel,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      if (!mounted) return;
      setState(() {
        _path = path;
        _stage = _Stage.ready;
      });
      await _install();
    } catch (e) {
      if (!mounted || _cancel.isCancelled) return;
      setState(() => _stage = _Stage.idle);
      toastError(e);
    }
  }

  Future<void> _install() async {
    try {
      await Updater.install(_path!);
    } on InstallPermissionNeeded catch (e) {
      showToast(e.toString(), type: ToastType.info);
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconBadge(Icons.system_update_rounded, size: 60, gradient: AppColors.brandGradient),
          ).animate().scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack, duration: 500.ms),
          const SizedBox(height: 14),
          Text('Update available', textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: 6),
          Text(
            [
              'Version ${u.version}',
              if (_current != null) 'you have $_current',
              if (u.sizeLabel.isNotEmpty) u.sizeLabel,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600),
          ),
          if (u.notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What\'s new', style: context.text.labelLarge),
                    const SizedBox(height: 6),
                    Text(_plainNotes(u.notes), style: context.text.bodyMedium?.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_stage) {
              _Stage.downloading => Column(
                key: const ValueKey('dl'),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progress == 0 ? 'Starting download…' : 'Downloading ${(_progress * 100).round()}%',
                    style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              _Stage.ready => GradientButton(
                key: const ValueKey('install'),
                label: 'Install update',
                icon: Icons.install_mobile_rounded,
                onPressed: _install,
              ),
              _Stage.idle => GradientButton(
                key: const ValueKey('go'),
                label: 'Update now',
                icon: Icons.download_rounded,
                onPressed: _download,
              ),
            },
          ),
          const SizedBox(height: 6),
          if (_stage == _Stage.idle) TextButton(onPressed: _later, child: const Text('Later')),
          if (_stage == _Stage.ready)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'If Android asks, allow TnP Student to install apps, then tap Install update again. '
                'Your sign-in and data stay as they are.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.palette.muted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  /// GitHub release notes are Markdown; show them as readable plain text.
  static String _plainNotes(String md) => md
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      .trim();
}
