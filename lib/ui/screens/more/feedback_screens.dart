import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _body = TextEditingController();
  String _type = 'query';
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(studentProvider);
    if (s == null) return;
    if (_body.text.trim().isEmpty) {
      showToast('Please enter your feedback or query.', type: ToastType.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(repositoryProvider).submitFeedback({
        'student_id': s.id,
        'email': s.email,
        'name': s.name,
        'roll_no': s.rollNumber,
        'branch': s.branch,
        'degree': s.degree,
        'batch': s.batch,
        'feedback_type': _type,
        'feedback_data': _body.text.trim(),
      });
      showToast('Feedback submitted!', type: ToastType.success);
      ref.invalidate(feedbacksProvider);
      if (mounted) context.pushReplacement('/more/my-feedbacks');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(studentProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback or Query'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/more/my-feedbacks'),
            icon: const Icon(Icons.history_rounded),
            label: const Text('History'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InitialsAvatar(name: s?.name ?? 'S', size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s?.name ?? '', style: context.text.titleSmall),
                      Text(
                        '${s?.rollNumber ?? ''} · ${s?.email ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).entrance(0),
          const SizedBox(height: 22),
          Text('What\'s this about?', style: context.text.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, e) in Catalog.feedbackTypes.entries.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() => _type = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _type == e.key ? AppColors.brandGradient : null,
                        color: _type == e.key ? null : context.palette.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _type == e.key ? Colors.transparent : context.palette.border),
                      ),
                      child: Column(
                        children: [
                          Icon(switch (e.key) {
                            'suggestion' => Icons.lightbulb_rounded,
                            'complaint' => Icons.report_rounded,
                            _ => Icons.help_rounded,
                          }, color: _type == e.key ? Colors.white : context.palette.muted),
                          const SizedBox(height: 6),
                          Text(
                            e.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _type == e.key ? Colors.white : context.colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ).entrance(1),
          const SizedBox(height: 22),
          Text('Details', style: context.text.titleSmall),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 12,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Describe your feedback or query in detail…',
              alignLabelWithHint: true,
            ),
          ).entrance(2),
          const SizedBox(height: 12),
          GradientButton(label: 'Submit', icon: Icons.send_rounded, loading: _sending, onPressed: _submit),
        ],
      ),
    );
  }
}

class MyFeedbacksScreen extends ConsumerStatefulWidget {
  const MyFeedbacksScreen({super.key});

  @override
  ConsumerState<MyFeedbacksScreen> createState() => _MyFeedbacksScreenState();
}

class _MyFeedbacksScreenState extends ConsumerState<MyFeedbacksScreen> {
  bool _resolvedOnly = false;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(feedbacksProvider(_resolvedOnly));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Feedbacks'),
        actions: [
          Row(
            children: [
              Text('Resolved', style: context.text.labelMedium),
              Switch(value: _resolvedOnly, onChanged: (v) => setState(() => _resolvedOnly = v)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/more/feedback'),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(feedbacksProvider(_resolvedOnly).future),
        child: AsyncView<List<FeedbackItem>>(
          value: list,
          onRetry: () => ref.invalidate(feedbacksProvider(_resolvedOnly)),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      icon: Icons.forum_outlined,
                      title: _resolvedOnly ? 'No resolved feedback yet' : 'No feedback yet',
                      subtitle: 'Your queries and their replies from TnP appear here.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _FeedbackCard(item: items[i]).entrance(i),
                ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({required this.item});
  final FeedbackItem item;

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.item;
    final typeLabel = Catalog.feedbackTypes[f.type] ?? f.type;
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Pill(typeLabel, color: AppColors.indigo, dense: true),
                const SizedBox(width: 8),
                Pill(
                  f.resolved ? 'Resolved' : 'Pending',
                  color: f.resolved ? AppColors.success : AppColors.warning,
                  icon: f.resolved ? Icons.check_rounded : Icons.hourglass_top_rounded,
                  dense: true,
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.expand_more_rounded, color: context.palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              f.body,
              maxLines: _open ? null : 2,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: context.text.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              'Created ${Fmt.dayTime(f.createdAt)}',
              style: context.text.bodySmall?.copyWith(color: context.palette.muted),
            ),
            if (_open) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (f.resolved ? AppColors.success : context.palette.muted).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    left: BorderSide(color: f.resolved ? AppColors.success : context.palette.muted, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 18,
                          color: f.resolved ? AppColors.success : context.palette.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f.resolved ? 'Reply from ${f.resolvedBy.isEmpty ? 'TnP' : f.resolvedBy}' : 'Awaiting reply',
                          style: context.text.labelLarge,
                        ),
                      ],
                    ),
                    if (f.resolved) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        f.reply.isEmpty ? '—' : f.reply,
                        style: context.text.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Resolved ${Fmt.dayTime(f.resolvedAt)}',
                        style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms),
            ],
          ],
        ),
      ),
    );
  }
}
