import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../data/repository.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import '../home_shell.dart';
import 'admit_card.dart';
import 'cgpa_update_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(studentProvider);
    if (s == null) return const Scaffold(body: SkeletonList());
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.crimson,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () async {
          try {
            await ref.read(authProvider.notifier).refreshProfile();
          } catch (e) {
            toastError(e);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, navBarInset(context)),
          children: [
            _ProfileHeader(student: s),
            const SizedBox(height: 14),
            _Actions(student: s).entrance(1),
            const SizedBox(height: 24),
            const SectionHeader('Academics', icon: Icons.school_rounded),
            _AcademicsCard(student: s).entrance(2),
            const SizedBox(height: 24),
            SectionHeader('Resumes', subtitle: 'Up to 3 — pick one when applying', icon: Icons.description_rounded),
            _ResumeSlots(student: s).entrance(3),
            const SizedBox(height: 24),
            SectionHeader(
              'Personal details',
              icon: Icons.person_rounded,
              trailing: TextButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ),
            _PersonalCard(student: s).entrance(4),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDeep.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.crimson.withValues(alpha: 0.4), Colors.transparent]),
              ),
            ),
          ),
          Column(
            children: [
              Hero(
                tag: 'me-avatar',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                  child: ClipOval(child: InitialsAvatar(name: s.name, size: 84, radius: 42)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.name,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                s.email,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in [
                    s.rollNumber,
                    '${s.degree} · ${s.branch}',
                    'Batch ${s.batch}',
                    if (s.campus.isNotEmpty) s.campus,
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.97, 0.97), curve: Curves.easeOut);
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.student});
  final Student student;

  void _drop(BuildContext context) {
    final s = student;
    if (!s.isCgpaUpdated) {
      showToast('Please update your CGPA first', type: ToastType.error);
      return;
    }
    if (Catalog.dropRules[s.courseType] == null) {
      showToast('Course drop option is not currently available for you.', type: ToastType.error);
      return;
    }
    if (s.courses.isEmpty) {
      showToast('No course-wise data available. Update your CGPA first.', type: ToastType.error);
      return;
    }
    context.push('/profile/drop');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = student;
    final actions = <(IconData, String, Color, VoidCallback)>[
      (Icons.qr_code_2_rounded, 'Hall card', AppColors.indigo, () => showAdmitCard(context, s)),
      (Icons.edit_note_rounded, 'Edit info', AppColors.info, () => context.push('/profile/edit')),
      (Icons.sync_rounded, 'Update CGPA', AppColors.crimson, () => openCgpaUpdate(context, s)),
      if (!s.lastSemGpaAvailable) (Icons.playlist_remove_rounded, 'Drop', AppColors.warning, () => _drop(context)),
    ];
    return Row(
      children: [
        for (final (i, a) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AppCard(
              onTap: a.$4,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                children: [
                  IconBadge(a.$1, color: a.$3, size: 40),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(
                        a.$2,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens the CGPA update sheet, or explains why it's unavailable.
/// The website hides the button when `cgpaUpdateEnabled` is false; the app
/// keeps it visible so students can always find it.
void openCgpaUpdate(BuildContext context, Student s) {
  if (s.cgpaUpdateEnabled) {
    showCgpaUpdateSheet(context);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 32),
      title: const Text('CGPA update is closed', textAlign: TextAlign.center),
      content: const Text(
        'The TnP office has switched off CGPA updates for your account right now. '
        'This option opens when they enable it (usually after results are declared). '
        'Pull down on this page to refresh later.',
        textAlign: TextAlign.center,
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

class _AcademicsCard extends StatelessWidget {
  const _AcademicsCard({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final cgpa = dbl(s.cgpa);
    final sems = List.generate(s.totalSemesters, (i) => dbl(s.semGpa(i + 1)));
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (cgpa ?? 0) / 10),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: v.clamp(0, 1),
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.palette.subtle,
                        color: AppColors.crimson,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cgpa == null ? '—' : (v * 10).toStringAsFixed(2),
                              style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text('CGPA', style: context.text.labelSmall?.copyWith(color: context.palette.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _kv(context, 'Class 10', '${displayNum(s.cgpa10th)}%'),
                    _kv(context, 'Class 12', '${displayNum(s.cgpa12th)}%'),
                    _kv(context, 'Graduation', displayNum(s.graduationGpa, empty: 'NA')),
                    _kv(context, 'Backlogs', displayNum(s.backlogs, empty: '0')),
                    _kv(context, 'Bans', displayNum(s.bans, empty: '0')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Semester-wise GPA', style: context.text.labelLarge),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 150, child: _SemesterChart(values: sems)),
          if (!s.lastSemGpaAvailable && str(s.cgpaBeforeDrop) != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'CGPA before drop: ${displayNum(s.cgpaBeforeDrop)}',
                style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!s.isCgpaUpdated) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.cgpaUpdateEnabled
                          ? 'Your CGPA isn\'t updated. Tap "Update CGPA" to import it from IMS.'
                          : 'Your CGPA isn\'t updated yet. CGPA updates are currently closed by TnP.',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          GradientButton(
            label: 'Update CGPA',
            icon: Icons.sync_rounded,
            height: 50,
            gradient: s.cgpaUpdateEnabled
                ? AppColors.brandGradient
                : const LinearGradient(colors: [Color(0xFF8A90A6), Color(0xFF6B7186)]),
            onPressed: () => openCgpaUpdate(context, s),
          ),
          if (!s.cgpaUpdateEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Currently closed by TnP',
                style: context.text.labelSmall?.copyWith(color: context.palette.muted, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: context.text.bodyMedium?.copyWith(color: context.palette.muted)),
        ),
        Text(v, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// Animated bar chart of semester GPAs.
class _SemesterChart extends StatelessWidget {
  const _SemesterChart({required this.values});
  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const maxH = 104.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, v) in values.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        v == null || v < 0 ? '—' : v.toStringAsFixed(v >= 10 ? 0 : 1),
                        style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: v == null || v < 0 ? 0.06 : (v / 10).clamp(0.06, 1)),
                        duration: Duration(milliseconds: 700 + i * 90),
                        curve: Curves.easeOutBack,
                        builder: (_, t, _) => Container(
                          height: maxH * t.clamp(0, 1.05),
                          decoration: BoxDecoration(
                            gradient: v == null
                                ? null
                                : const LinearGradient(
                                    colors: [AppColors.coral, AppColors.crimson],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                            color: v == null ? context.palette.subtle : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('S${i + 1}', style: context.text.labelSmall?.copyWith(color: context.palette.muted)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------- Resumes --

class _ResumeSlots extends ConsumerStatefulWidget {
  const _ResumeSlots({required this.student});
  final Student student;

  @override
  ConsumerState<_ResumeSlots> createState() => _ResumeSlotsState();
}

class _ResumeSlotsState extends ConsumerState<_ResumeSlots> {
  int? _busySlot;
  double _progress = 0;

  Future<void> _upload(int index) async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      showToast('File is larger than 10 MB', type: ToastType.error);
      return;
    }
    setState(() {
      _busySlot = index;
      _progress = 0;
    });
    try {
      await ref
          .read(repositoryProvider)
          .uploadResume(
            PickedUpload(name: f.name, bytes: bytes),
            index,
            onProgress: (p) => mounted ? setState(() => _progress = p) : null,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(resumesProvider);
      showToast('Resume has been uploaded', type: ToastType.success);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Future<void> _delete(int index, ResumeFile r) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete resume?',
      message: '"${r.name}" will be removed from your profile.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busySlot = index);
    try {
      await ref.read(repositoryProvider).deleteResume(r.uploadId);
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(resumesProvider);
      showToast('Resume has been deleted', type: ToastType.success);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumes = widget.student.resumes;
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _slot(context, i, i < resumes.length ? resumes[i] : null),
          ),
      ],
    );
  }

  Widget _slot(BuildContext context, int i, ResumeFile? r) {
    final busy = _busySlot == i;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: r == null ? (busy ? null : () => _upload(i)) : () => openLink(context, r.url, title: r.name),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: r == null ? null : AppColors.brandGradient,
                  color: r == null ? context.palette.subtle : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  r == null ? Icons.add_rounded : Icons.picture_as_pdf_rounded,
                  color: r == null ? context.palette.muted : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resume ${i + 1}', style: context.text.labelMedium?.copyWith(color: context.palette.muted)),
                    Text(
                      r?.name ?? (busy ? 'Uploading…' : 'Tap to upload a PDF'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              else if (r != null) ...[
                IconButton(tooltip: 'Replace', onPressed: () => _upload(i), icon: const Icon(Icons.swap_horiz_rounded)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(i, r),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                ),
              ] else
                const Icon(Icons.upload_rounded, color: AppColors.crimson),
            ],
          ),
          if (busy && r == null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 5),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({required this.student});
  final Student student;

  String _mask(String v) => v.length <= 4 ? v : '${'•' * (v.length - 4)}${v.substring(v.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final s = student;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          InfoRow(icon: Icons.wc_rounded, label: 'Gender', value: s.gender),
          InfoRow(icon: Icons.cake_rounded, label: 'Date of birth', value: s.dob),
          InfoRow(icon: Icons.bloodtype_rounded, label: 'Blood group', value: s.bloodGroup),
          InfoRow(icon: Icons.groups_rounded, label: 'Category', value: s.category),
          InfoRow(icon: Icons.school_rounded, label: 'College email', value: s.email),
          InfoRow(icon: Icons.alternate_email_rounded, label: 'Personal email', value: s.personalEmail),
          InfoRow(icon: Icons.phone_rounded, label: 'Contact number', value: s.contactNumber),
          InfoRow(icon: Icons.phone_forwarded_rounded, label: 'Alternate contact', value: s.altContactNumber),
          InfoRow(icon: Icons.home_rounded, label: 'Current address', value: s.presentAddress),
          InfoRow(icon: Icons.cottage_rounded, label: 'Permanent address', value: s.permAddress),
          InfoRow(icon: Icons.fingerprint_rounded, label: 'Aadhaar', value: _mask(s.aadhar)),
          InfoRow(icon: Icons.credit_card_rounded, label: 'PAN', value: _mask(s.pan)),
        ],
      ),
    );
  }
}
