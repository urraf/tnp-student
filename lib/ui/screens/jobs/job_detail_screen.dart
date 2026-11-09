import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../data/repository.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import '../notices/notice_detail_screen.dart' show AttachmentTile;

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(id));
    return Scaffold(
      body: AsyncView<CompanyEvent>(
        value: job,
        onRetry: () => ref.invalidate(jobDetailProvider(id)),
        loading: _Skeleton(id: id),
        data: (e) => _Body(event: e),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});
  final CompanyEvent event;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(eligibilityProvider(event.id));
    ref.invalidate(jobDetailProvider(event.id));
    await ref.read(jobDetailProvider(event.id).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final eligibility = ref.watch(eligibilityProvider(e.id));
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              _Header(event: e),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                sliver: SliverList.list(
                  children: [
                    _QuickStats(event: e).entrance(0),
                    const SizedBox(height: 16),
                    _EligibilityCard(event: e, value: eligibility).entrance(1),
                    const SizedBox(height: 22),
                    const SectionHeader('Opening overview', icon: Icons.dashboard_customize_rounded),
                    _Overview(event: e).entrance(2),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const SectionHeader('Job description', icon: Icons.description_rounded),
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: SelectableText(e.description, style: context.text.bodyLarge?.copyWith(height: 1.6)),
                      ).entrance(3),
                    ],
                    if (e.attachments.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader(
                        'Attached documents',
                        subtitle: '${e.attachments.length} file(s)',
                        icon: Icons.attach_file_rounded,
                      ),
                      for (final (i, a) in e.attachments.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AttachmentTile(attachment: a).entrance(i + 4),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ActionBar(event: e, eligibility: eligibility),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});
  final CompanyEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 250,
      backgroundColor: AppColors.navyDeep,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(e.companyName, style: const TextStyle(color: Colors.white)),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              Positioned(
                right: -70,
                top: -50,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [AppColors.crimson.withValues(alpha: 0.45), Colors.transparent]),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'job-logo-${e.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CompanyLogo(name: e.companyName, size: 64),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        e.jobTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (e.type.isNotEmpty)
                            Pill(
                              e.type,
                              color: AppColors.tagColor(e.type),
                              filled: true,
                              icon: AppColors.tagIcon(e.type),
                            ),
                          Pill(e.displayStatus, color: Colors.white, icon: Icons.circle, dense: false),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.event});
  final CompanyEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    Widget tile(IconData icon, String label, String value, Color color) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(label, style: context.text.labelSmall?.copyWith(color: context.palette.muted)),
            const SizedBox(height: 2),
            Text(
              value.isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile(Icons.payments_rounded, 'CTC / Stipend', e.stipend, AppColors.success),
        const SizedBox(width: 10),
        tile(Icons.place_rounded, 'Location', e.placeOfPosting, AppColors.info),
        const SizedBox(width: 10),
        tile(
          Icons.timer_rounded,
          'Deadline',
          e.lastDate == null ? '' : Fmt.countdown(e.lastDate),
          e.registrationClosed ? AppColors.danger : AppColors.warning,
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.event});
  final CompanyEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final branches = e.branchesAllowed;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          InfoRow(icon: Icons.place_rounded, label: 'Place of posting', value: e.placeOfPosting),
          InfoRow(icon: Icons.groups_rounded, label: 'Batch', value: e.batch),
          InfoRow(icon: Icons.payments_rounded, label: 'CTC / Stipend', value: e.stipend),
          InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'CTC / Stipend info',
            value: e.stipendInfo ?? 'Not mentioned',
          ),
          if (e.showsCriteria) ...[
            InfoRow(icon: Icons.grade_rounded, label: 'Minimum CGPA', value: e.cgpa),
            InfoRow(icon: Icons.category_rounded, label: 'Category', value: e.category),
            InfoRow(icon: Icons.rule_rounded, label: 'Backlogs allowed', value: e.backlogs),
            if (branches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(Icons.account_tree_rounded, size: 36, color: AppColors.indigo),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allowed branches',
                            style: context.text.labelMedium?.copyWith(color: context.palette.muted),
                          ),
                          const SizedBox(height: 6),
                          for (final entry in branches.entries) ...[
                            Text(entry.key, style: context.text.labelLarge),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final b in entry.value) Pill(b, dense: true, color: AppColors.indigo)],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            InfoRow(icon: Icons.event_busy_rounded, label: 'Registration last date', value: Fmt.dayTime(e.lastDate)),
          ],
          InfoRow(icon: Icons.support_agent_rounded, label: 'Coordinators', value: e.coordinators),
          if (e.additionalInfo != null)
            InfoRow(icon: Icons.notes_rounded, label: 'Additional info', value: e.additionalInfo!),
          if (e.formLink != null)
            InfoRow(
              icon: Icons.link_rounded,
              label: 'Form link',
              value: 'Open form',
              onTap: () => openLink(context, e.formLink!),
            ),
        ],
      ),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({required this.event, required this.value});
  final CompanyEvent event;
  final AsyncValue<Eligibility> value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        alignment: Alignment.topCenter,
        child: value.when(
          loading: () => Skeleton(
            child: Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SkeletonBox(width: 22, height: 22, radius: 11),
                      SizedBox(width: 12),
                      SkeletonBox(width: 160),
                    ],
                  ),
                ),
              ),
            ),
          ),
          error: (err, _) => Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(child: Text('Eligibility check failed: ${ApiException.from(err).message}')),
            ],
          ),
          data: (el) {
            final keys = Eligibility.criteria.where((c) {
              if (c.$1.startsWith('percentage_')) return event.optionalCriteria;
              return true;
            }).toList();
            final passed = keys.where((c) => el.passes(c.$1)).length;
            final good = el.eligible && !el.alreadyPlaced;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      good ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                      color: good ? AppColors.success : AppColors.danger,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(good ? 'You\'re eligible' : 'Not eligible', style: context.text.titleMedium),
                          Text(
                            '$passed of ${keys.length} criteria met · checked ${Fmt.day(DateTime.now())}',
                            style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: keys.isEmpty ? 0 : passed / keys.length),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: context.palette.subtle,
                          color: good ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                if (el.alreadyApplied || el.alreadyPlaced) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (el.alreadyPlaced ? AppColors.danger : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      el.alreadyPlaced
                          ? 'You cannot apply because you are already placed.'
                          : 'You have already applied for this opportunity.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: el.alreadyPlaced ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, c) in keys.indexed)
                      _CriterionChip(label: c.$2, ok: el.passes(c.$1))
                          .animate()
                          .fadeIn(delay: (40 * i).ms)
                          .scale(begin: const Offset(0.85, 0.85), delay: (40 * i).ms, curve: Curves.easeOutBack),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CriterionChip extends StatelessWidget {
  const _CriterionChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: context.colors.onSurface),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Action bar --

class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.event, required this.eligibility});
  final CompanyEvent event;
  final AsyncValue<Eligibility> eligibility;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final ok = await confirmDialog(
      context,
      title: 'Withdraw application?',
      message: 'You will be removed from ${widget.event.companyName}\'s applicant list.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final user = ref.read(authProvider).user;
      final msg = await ref
          .read(repositoryProvider)
          .withdraw(eventId: widget.event.id, studentId: user?.studentId ?? '');
      showToast(msg ?? 'Application withdrawn', type: ToastType.success);
      ref.invalidate(eligibilityProvider(widget.event.id));
      ref.invalidate(applicationsProvider);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (_) => ApplySheet(event: widget.event),
    );
    if (applied == true) {
      ref.invalidate(eligibilityProvider(widget.event.id));
      ref.invalidate(applicationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final el = widget.eligibility.value;
    final closed = e.registrationClosed;

    String? reason;
    Widget button;
    if (el == null) {
      button = GradientButton(label: 'Checking eligibility…', loading: widget.eligibility.isLoading, onPressed: null);
    } else if (el.alreadyApplied) {
      button = OutlinedButton.icon(
        onPressed: closed || _busy ? null : _withdraw,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.undo_rounded),
        label: const Text('Withdraw application'),
      );
      reason = closed ? 'Applied ✓ · Registration closed, withdrawal disabled' : 'Applied ✓';
    } else {
      if (closed) {
        reason = 'Registration date has passed';
      } else if (el.alreadyPlaced) {
        reason = 'Already placed';
      } else if (!el.eligible) {
        reason = 'You don\'t meet the eligibility criteria';
      }
      button = GradientButton(
        label: closed ? 'Registration closed' : 'Apply now',
        icon: closed ? Icons.lock_rounded : Icons.send_rounded,
        onPressed: reason == null ? _apply : null,
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border(top: BorderSide(color: context.palette.border)),
        boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason != null) ...[
            Text(
              reason,
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(
                color: reason.startsWith('Applied') ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          button,
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
  }
}

// ------------------------------------------------------------ Apply sheet --

class ApplySheet extends ConsumerStatefulWidget {
  const ApplySheet({super.key, required this.event});
  final CompanyEvent event;

  @override
  ConsumerState<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<ApplySheet> {
  /// Index into the resume list (URLs aren't guaranteed unique).
  int _resumeIndex = 0;
  String? _resumeUrl;
  final Map<int, String> _text = {};
  final Map<int, String> _single = {};
  final Map<int, Set<String>> _multi = {};
  final Map<int, PickedUpload> _files = {};
  bool _submitting = false;
  String _progressLabel = '';

  List<AdditionalQuestion> get _questions =>
      widget.event.hasAdditionalQuestions ? widget.event.additionalQuestions : const [];

  String? _answerFor(int i, AdditionalQuestion q) {
    switch (q.type) {
      case 'multi':
        final s = _multi[i];
        return (s == null || s.isEmpty) ? null : q.options.where(s.contains).join(', ');
      case 'single':
        return _single[i];
      case 'file':
        return _files[i]?.name;
      default:
        final t = _text[i]?.trim();
        return (t == null || t.isEmpty) ? null : t;
    }
  }

  bool get _complete {
    if (_resumeUrl == null) return false;
    for (final (i, q) in _questions.indexed) {
      if (_answerFor(i, q) == null) return false;
    }
    return true;
  }

  Future<void> _pickFile(int i) async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _files[i] = PickedUpload(name: f.name, bytes: bytes));
  }

  Future<void> _submit() async {
    if (!_complete) return;
    setState(() => _submitting = true);
    final repo = ref.read(repositoryProvider);
    try {
      final answers = <Json>[];
      for (final (i, q) in _questions.indexed) {
        var ans = _answerFor(i, q)!;
        if (q.type == 'file') {
          setState(() => _progressLabel = 'Uploading ${_files[i]!.name}…');
          final up = await repo.uploadFile(_files[i]!);
          final url = up.isEmpty ? null : str(up.first['url']);
          if (url == null) throw ApiException('Failed to upload ${_files[i]!.name}');
          ans = url;
        }
        answers.add({...q.raw, 'expectedAns': ans});
      }
      setState(() => _progressLabel = 'Submitting application…');
      final user = ref.read(authProvider).user;
      await repo.apply(
        eventId: widget.event.id,
        studentId: user?.studentId ?? '',
        resumeUrl: _resumeUrl!,
        answers: _questions.isEmpty ? null : answers,
      );
      HapticFeedback.mediumImpact();
      showToast('Successfully applied to ${widget.event.companyName}! 🎉', type: ToastType.success);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressLabel = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumes = ref.watch(resumesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: _questions.isEmpty ? 0.6 : 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Row(
                    children: [
                      CompanyLogo(name: widget.event.companyName, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apply to ${widget.event.companyName}',
                              style: context.text.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.event.jobTitle,
                              style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Choose a resume', style: context.text.titleSmall),
                  const SizedBox(height: 10),
                  resumes.when(
                    loading: () => const Skeleton(child: SkeletonBox(height: 64, radius: 16)),
                    error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(resumesProvider)),
                    data: (list) {
                      if (list.isEmpty) {
                        return AppCard(
                          shadow: false,
                          child: Column(
                            children: [
                              const Text('You haven\'t uploaded a resume yet.'),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.go('/profile');
                                },
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Upload in Profile'),
                              ),
                            ],
                          ),
                        );
                      }
                      final idx = _resumeIndex.clamp(0, list.length - 1);
                      if (_resumeUrl != list[idx].url) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _resumeUrl = list[idx].url);
                        });
                      }
                      return Column(
                        children: [
                          for (final (i, r) in list.indexed)
                            _SelectTile(
                              title: r.name,
                              icon: Icons.picture_as_pdf_rounded,
                              selected: idx == i,
                              onTap: () => setState(() {
                                _resumeIndex = i;
                                _resumeUrl = r.url;
                              }),
                              trailing: IconButton(
                                tooltip: 'Preview',
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: () => openLink(context, r.url, title: r.name),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  for (final (i, q) in _questions.indexed) ...[
                    const SizedBox(height: 20),
                    Text(q.question, style: context.text.titleSmall?.copyWith(height: 1.35)),
                    const SizedBox(height: 10),
                    _questionInput(i, q),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.palette.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_progressLabel.isNotEmpty) ...[
                    Text(_progressLabel, style: context.text.labelMedium?.copyWith(color: context.palette.muted)),
                    const SizedBox(height: 8),
                  ] else if (!_complete) ...[
                    Text(
                      'Answer all questions to apply',
                      style: context.text.labelMedium?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                  ],
                  GradientButton(
                    label: 'Submit application',
                    icon: Icons.send_rounded,
                    loading: _submitting,
                    onPressed: _complete ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionInput(int i, AdditionalQuestion q) {
    switch (q.type) {
      case 'single':
        return Column(
          children: [
            for (final o in q.options)
              _SelectTile(
                title: o,
                icon: _single[i] == o ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                selected: _single[i] == o,
                onTap: () => setState(() => _single[i] = o),
              ),
          ],
        );
      case 'multi':
        final set = _multi.putIfAbsent(i, () => <String>{});
        return Column(
          children: [
            for (final o in q.options)
              _SelectTile(
                title: o,
                icon: set.contains(o) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                selected: set.contains(o),
                onTap: () => setState(() => set.contains(o) ? set.remove(o) : set.add(o)),
              ),
          ],
        );
      case 'file':
        final f = _files[i];
        return _SelectTile(
          title: f?.name ?? 'Choose a PDF file',
          icon: f == null ? Icons.upload_file_rounded : Icons.picture_as_pdf_rounded,
          selected: f != null,
          onTap: () => _pickFile(i),
          trailing: f == null
              ? null
              : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _files.remove(i))),
        );
      default:
        return TextFormField(
          initialValue: _text[i],
          minLines: 1,
          maxLines: 5,
          onChanged: (v) => setState(() => _text[i] = v),
          decoration: InputDecoration(hintText: q.hint.isEmpty ? 'Your answer' : q.hint),
        );
    }
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.fromLTRB(
            14,
            trailing == null ? 14 : 4,
            trailing == null ? 14 : 4,
            trailing == null ? 14 : 4,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.crimson.withValues(alpha: context.isDark ? 0.16 : 0.06) : context.palette.field,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.crimson : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.crimson : context.palette.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 250 + MediaQuery.paddingOf(context).top,
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
            ),
          ),
        ),
        Expanded(
          child: Skeleton(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 100, radius: 20)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 100, radius: 20)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 100, radius: 20)),
                  ],
                ),
                SizedBox(height: 16),
                SkeletonBox(height: 160, radius: 20),
                SizedBox(height: 16),
                SkeletonBox(height: 320, radius: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
