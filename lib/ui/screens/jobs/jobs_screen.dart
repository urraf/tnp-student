import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _type = 'All';
  bool _openOnly = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 500) ref.read(jobsProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  List<CompanyEvent> _filter(List<CompanyEvent> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((e) {
      if (_type != 'All' && e.type != _type) return false;
      if (_openOnly && e.registrationClosed) return false;
      if (q.isEmpty) return true;
      return e.jobTitle.toLowerCase().contains(q) || e.companyName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsProvider);
    final items = _filter(state.items);
    final openCount = state.items.where((e) => !e.registrationClosed).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: TabHeader(
                  title: 'Job Profiles',
                  subtitle: state.items.isEmpty
                      ? 'Opportunities for your batch'
                      : '$openCount open · ${state.items.length} loaded',
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search company or role…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              contentPadding: EdgeInsets.zero,
                              fillColor: context.palette.card,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: context.palette.border),
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(_search.clear),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Show open only',
                        child: Pressable(
                          onTap: () => setState(() => _openOnly = !_openOnly),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              gradient: _openOnly ? AppColors.brandGradient : null,
                              color: _openOnly ? null : context.palette.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _openOnly ? Colors.transparent : context.palette.border),
                            ),
                            child: Icon(
                              Icons.lock_open_rounded,
                              color: _openOnly ? Colors.white : context.palette.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final t in ['All', ...Catalog.eventTypes])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: _type == t,
                            onSelected: (_) => setState(() => _type = t),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _type == t ? AppColors.crimson : context.colors.onSurface,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ..._list(state, items),
              SliverToBoxAdapter(child: SizedBox(height: navBarInset(context))),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _list(PagedState<CompanyEvent> state, List<CompanyEvent> items) {
    if (state.loading && state.items.isEmpty) {
      return [const SliverToBoxAdapter(child: SkeletonList(count: 5, shrinkWrap: true))];
    }
    if (state.error != null && state.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(error: state.error!, onRetry: () => ref.read(jobsProvider.notifier).refresh()),
        ),
      ];
    }
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.work_off_outlined,
            title: state.items.isEmpty ? 'No openings yet' : 'Nothing matches your filters',
            subtitle: state.items.isEmpty
                ? 'New company events for your batch will show up here.'
                : (state.hasMore ? 'Try loading more or clearing the filters.' : 'Try clearing the filters.'),
            action: state.items.isEmpty
                ? null
                : Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _type = 'All';
                          _openOnly = false;
                          _search.clear();
                        }),
                        child: const Text('Clear filters'),
                      ),
                      if (state.hasMore)
                        FilledButton(
                          onPressed: () => ref.read(jobsProvider.notifier).loadMore(),
                          child: const Text('Load more'),
                        ),
                    ],
                  ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => JobCard(event: items[i]).entrance(i % 14),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: state.loadingMore
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6))
                : state.hasMore
                ? TextButton.icon(
                    onPressed: () => ref.read(jobsProvider.notifier).loadMore(),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Load more'),
                  )
                : Text(
                    'You\'ve seen them all 🎯',
                    style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    ];
  }
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.event});
  final CompanyEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final closed = e.registrationClosed;
    return AppCard(
      onTap: () => context.push('/job/${e.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'job-logo-${e.id}',
                child: CompanyLogo(name: e.companyName, size: 52),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.jobTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.companyName.isEmpty ? '—' : e.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(e.displayStatus, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.type.isNotEmpty)
                Pill(e.type, color: AppColors.tagColor(e.type), icon: AppColors.tagIcon(e.type), dense: true),
              if (e.placeOfPosting.isNotEmpty) Pill(e.placeOfPosting, icon: Icons.place_rounded, dense: true),
              if (e.stipend.isNotEmpty)
                Pill(e.stipend, icon: Icons.payments_rounded, color: AppColors.success, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 16, color: context.palette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Apply by ${Fmt.dayTime(e.lastDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (e.lastDate != null)
                  Text(
                    Fmt.countdown(e.lastDate),
                    style: context.text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: closed ? AppColors.danger : AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
