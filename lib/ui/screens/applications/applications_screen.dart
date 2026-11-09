import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(applicationsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.refresh(applicationsProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: TabHeader(
                  title: 'My Applications',
                  subtitle: apps.hasValue
                      ? '${apps.requireValue.length} active application(s)'
                      : 'Track every role you\'ve applied to',
                ),
              ),
              SliverToBoxAdapter(
                child: AsyncView<List<Application>>(
                  value: apps,
                  onRetry: () => ref.invalidate(applicationsProvider),
                  loading: const SkeletonList(count: 4, shrinkWrap: true),
                  data: (list) {
                    if (list.isEmpty) {
                      return EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No applications yet',
                        subtitle: 'When you apply to a company it will appear here.',
                        action: FilledButton.icon(
                          onPressed: () => context.go('/jobs'),
                          icon: const Icon(Icons.work_rounded),
                          label: const Text('Browse openings'),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        _Summary(list: list),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _ApplicationCard(app: list[i]).entrance(i),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: navBarInset(context))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list});
  final List<Application> list;

  @override
  Widget build(BuildContext context) {
    final open = list.where((a) => !(a.event?.registrationClosed ?? true)).length;
    final types = <String, int>{};
    for (final a in list) {
      final t = a.event?.type ?? '';
      if (t.isNotEmpty) types[t] = (types[t] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AppCard(
        gradient: AppColors.heroGradient,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _stat('${list.length}', 'Applied'),
            _stat('$open', 'Still open'),
            _stat('${list.length - open}', 'Closed'),
          ],
        ),
      ).entrance(0),
    );
  }

  Widget _stat(String v, String l) => Expanded(
    child: Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: double.tryParse(v) ?? 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, x, _) => Text(
            x.round().toString(),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          l,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ],
    ),
  );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app});
  final Application app;

  @override
  Widget build(BuildContext context) {
    final e = app.event;
    final name = e?.companyName ?? '';
    return AppCard(
      onTap: e == null ? null : () => context.push('/job/${e.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CompanyLogo(name: name.isEmpty ? 'No Company' : name, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e?.jobTitle ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'No company' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.palette.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if ((e?.status ?? '').isNotEmpty) StatusPill(e!.status, dense: true),
                    if ((e?.type ?? '').isNotEmpty) Pill(e!.type, color: AppColors.tagColor(e.type), dense: true),
                    if (e?.lastDate != null)
                      Pill('Deadline ${Fmt.day(e!.lastDate)}', icon: Icons.event_rounded, dense: true),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.palette.muted),
        ],
      ),
    );
  }
}
