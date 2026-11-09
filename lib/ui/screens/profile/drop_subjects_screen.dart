import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/auth.dart';
import '../../widgets/common.dart';

/// Course-drop planner (port of the web DropSubjects modal), with a live
/// CGPA preview and the same "recommendation" heuristic.
class DropSubjectsScreen extends ConsumerStatefulWidget {
  const DropSubjectsScreen({super.key});

  @override
  ConsumerState<DropSubjectsScreen> createState() => _DropSubjectsScreenState();
}

class _DropSubjectsScreenState extends ConsumerState<DropSubjectsScreen> {
  final _selected = <String>[];
  final _recommended = <String>{};
  String _query = '';
  bool _submitting = false;

  Student get _s => ref.read(studentProvider)!;

  ({int maxCredits, int maxSubjects})? get _rule => Catalog.dropRules[_s.courseType];

  List<Course> get _courses => _s.courses.where((c) => c.credits > 0).toList();

  int _creditsOf(Iterable<String> codes) =>
      _courses.where((c) => codes.contains(c.code)).fold(0, (a, c) => a + c.credits);

  /// Same formula as the web: overall totals minus dropped courses.
  String _cgpaAfter(List<String> dropped) {
    final drop = _s.courses.where((c) => dropped.contains(c.code));
    final dCredits = drop.fold<int>(0, (a, c) => a + c.credits);
    final dPoints = drop.fold<int>(0, (a, c) => a + c.creditPoints);
    final totalPoints = _s.semesterWise.fold<int>(0, (a, s) => a + (integer(s['totalCreditPoints']) ?? 0));
    final totalCredits = _s.semesterWise.fold<int>(0, (a, s) => a + (integer(s['totalCredit']) ?? 0));
    if (totalCredits - dCredits <= 0) return '0';
    return ((totalPoints - dPoints) / (totalCredits - dCredits)).toStringAsFixed(2);
  }

  void _toggle(Course c) {
    final rule = _rule!;
    setState(() {
      if (_selected.contains(c.code)) {
        _selected.remove(c.code);
        return;
      }
      if (_selected.length >= rule.maxSubjects) {
        showToast('Maximum ${rule.maxSubjects} subject(s) can be dropped', type: ToastType.error);
        return;
      }
      if (_creditsOf(_selected) + c.credits > rule.maxCredits) {
        showToast('Maximum ${rule.maxCredits} credits can be dropped', type: ToastType.error);
        return;
      }
      _selected.add(c.code);
    });
  }

  /// Greedy: drop lowest grade-per-credit courses while it improves CGPA.
  void _recommend() {
    final rule = _rule!;
    final courses = _courses;
    double cgpaOf(List<Course> list) {
      final cr = list.fold<int>(0, (a, c) => a + c.credits);
      final pts = list.fold<int>(0, (a, c) => a + c.creditPoints);
      return cr == 0 ? 0 : pts / cr;
    }

    final sorted = [...courses]..sort((a, b) => a.gpa.compareTo(b.gpa));
    var best = cgpaOf(courses);
    var bestDrop = <Course>[];
    final current = <Course>[];
    var credits = 0;
    for (final c in sorted) {
      if (current.length >= rule.maxSubjects || credits + c.credits > rule.maxCredits) break;
      current.add(c);
      credits += c.credits;
      final remaining = courses.where((x) => !current.any((d) => d.code == x.code)).toList();
      final v = cgpaOf(remaining);
      if (v > best) {
        best = v;
        bestDrop = [...current];
      }
    }
    setState(() {
      _recommended
        ..clear()
        ..addAll(bestDrop.map((c) => c.code));
      _selected
        ..clear()
        ..addAll(bestDrop.map((c) => c.code));
    });
    showToast(
      bestDrop.isEmpty ? 'Dropping won\'t improve your CGPA' : 'Recommended ${bestDrop.length} course(s)',
      type: ToastType.info,
    );
  }

  Future<void> _submit() async {
    final ok = await confirmDialog(
      context,
      title: 'Confirm drop',
      message: 'Drop ${_selected.join(', ')}? Your CGPA will become ${_cgpaAfter(_selected)}.',
      confirmLabel: 'Drop',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _submitting = true);
    try {
      await ref.read(repositoryProvider).dropCourses(_selected);
      await ref.read(authProvider.notifier).refreshProfile();
      showToast('Courses dropped successfully', type: ToastType.success);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rule = _rule;
    if (rule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Drop subjects')),
        body: const EmptyState(
          icon: Icons.block_rounded,
          title: 'Not available',
          subtitle: 'Course drop option is not currently available for you.',
        ),
      );
    }
    final q = _query.toLowerCase();
    final list = _courses.where((c) => c.code.toLowerCase().contains(q) || c.title.toLowerCase().contains(q)).toList();
    final credits = _creditsOf(_selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop subjects'),
        actions: [
          TextButton.icon(
            onPressed: _recommend,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Suggest'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: AppCard(
              gradient: AppColors.heroGradient,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CGPA after drop',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (c, a) => ScaleTransition(
                            scale: a,
                            child: FadeTransition(opacity: a, child: c),
                          ),
                          child: Text(
                            _cgpaAfter(_selected),
                            key: ValueKey(_selected.join()),
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          'Before drop: ${displayNum(_s.cgpaBeforeDrop ?? _s.cgpa)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _meter('Subjects', _selected.length, rule.maxSubjects),
                      const SizedBox(height: 10),
                      _meter('Credits', credits, rule.maxCredits),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Search courses…', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = list[i];
                final sel = _selected.contains(c.code);
                final rec = _recommended.contains(c.code);
                return Pressable(
                  onTap: _submitting ? null : () => _toggle(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.crimson.withValues(alpha: context.isDark ? 0.16 : 0.06)
                          : context.palette.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? AppColors.crimson : context.palette.border, width: sel ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: sel ? AppColors.crimson : context.palette.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(c.code, style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  if (rec) ...[
                                    const SizedBox(width: 6),
                                    const Pill(
                                      'Suggested',
                                      color: AppColors.info,
                                      icon: Icons.auto_awesome_rounded,
                                      dense: true,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c.type.isEmpty ? '' : '${c.type} · '}${c.credits} credits',
                                style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: StatusPill.colorFor(
                                  c.gpa >= 7
                                      ? 'open'
                                      : c.gpa >= 5
                                      ? 'pending'
                                      : 'rejected',
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(c.grade, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.gpa.toStringAsFixed(1),
                              style: context.text.labelSmall?.copyWith(color: context.palette.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).entrance(i % 12, baseMs: 25);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: context.palette.card,
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: GradientButton(
          label: _selected.isEmpty ? 'Select courses to drop' : 'Confirm drop (${_selected.length})',
          icon: Icons.playlist_remove_rounded,
          loading: _submitting,
          onPressed: _selected.isEmpty ? null : _submit,
        ),
      ),
    );
  }

  Widget _meter(String label, int v, int max) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '$v / $max',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: 90,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: max == 0 ? 0 : v / max),
            duration: const Duration(milliseconds: 300),
            builder: (_, t, _) => LinearProgressIndicator(
              value: t,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              color: AppColors.coral,
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5)),
    ],
  );
}
