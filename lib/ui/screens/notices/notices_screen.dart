import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import '../home_shell.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(noticeFilterProvider).search;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(noticesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(noticeFilterProvider.notifier).setSearch(q.trim());
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticesProvider);
    final filter = ref.watch(noticeFilterProvider);
    final student = ref.watch(studentProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.crimson,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => ref.read(noticesProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _HeroCard(student: student),
                ),
              ),
            ),
            if (student != null && (student.banStatus || !student.isCgpaUpdated))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _AlertBanner(student: student),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Announcements', style: context.text.titleLarge)),
                    if (state.items.isNotEmpty)
                      Text(
                        '${state.items.length}${state.hasMore ? '+' : ''}',
                        style: context.text.labelLarge?.copyWith(color: context.palette.muted),
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeader(
                height: 132,
                child: _Filters(search: _search, onSearch: _onSearch, filter: filter),
              ),
            ),
            ..._buildList(state),
            SliverToBoxAdapter(child: SizedBox(height: navBarInset(context))),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList(PagedState<Announcement> state) {
    if (state.loading && state.items.isEmpty) {
      return [const SliverToBoxAdapter(child: SkeletonList(count: 5, shrinkWrap: true))];
    }
    if (state.error != null && state.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(error: state.error!, onRetry: () => ref.read(noticesProvider.notifier).refresh()),
        ),
      ];
    }
    if (state.items.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You\'re all caught up!',
            subtitle: 'No announcements match. Check back later for new updates.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (context, i) => _TimelineTile(
            notice: state.items[i],
            first: i == 0,
            last: i == state.items.length - 1 && !state.hasMore,
          ).entrance(i % 12),
        ),
      ),
      SliverToBoxAdapter(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: state.loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
                  ),
                )
              : state.error != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => ref.read(noticesProvider.notifier).loadMore(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Couldn\'t load more — retry'),
                    ),
                  ),
                )
              : !state.hasMore
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'That\'s everything ✨',
                      style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : const SizedBox(height: 20),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------- Header --

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.student});
  final Student? student;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = student;
    final first = (s?.name ?? '').split(' ').first;
    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
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
            right: -50,
            top: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.crimson.withValues(alpha: 0.45), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.coral.withValues(alpha: 0.25), Colors.transparent]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting 👋',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          first.isEmpty ? 'Student' : first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.headlineSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Hero(
                      tag: 'me-avatar',
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                        child: ClipOval(child: InitialsAvatar(name: s?.name ?? 'S', size: 48, radius: 24)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (s?.rollNumber.isNotEmpty ?? false) _glassChip(Icons.badge_outlined, s!.rollNumber),
                  if (s?.branch.isNotEmpty ?? false)
                    _glassChip(Icons.account_tree_outlined, '${s!.degree} · ${s.branch}'),
                  if (s?.batch.isNotEmpty ?? false) _glassChip(Icons.calendar_month_outlined, 'Batch ${s!.batch}'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _stat('CGPA', displayNum(s?.cgpa)),
                  _divider(),
                  _stat('Backlogs', displayNum(s?.backlogs, empty: '0')),
                  _divider(),
                  _stat('Resumes', '${s?.resumes.length ?? 0}/3'),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _glassChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12));
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final banned = student.banStatus;
    final color = banned ? AppColors.danger : AppColors.warning;
    return AppCard(
      onTap: banned ? null : () => context.go('/profile'),
      color: color.withValues(alpha: context.isDark ? 0.15 : 0.08),
      borderColor: color.withValues(alpha: 0.35),
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(banned ? Icons.block_rounded : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              banned
                  ? 'You are banned from this platform. Please contact the TnP office.'
                  : 'Update your CGPA from IMS to apply for companies.',
              style: TextStyle(fontWeight: FontWeight.w600, color: color, height: 1.35),
            ),
          ),
          if (!banned) Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).shimmer(delay: 700.ms, duration: 1200.ms, color: color.withValues(alpha: 0.25));
  }
}

// ---------------------------------------------------------------- Filters --

class _FilterHeader extends SliverPersistentHeaderDelegate {
  _FilterHeader({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.palette.background,
      child: Stack(
        children: [
          child,
          if (overlapsContent || shrinkOffset > 0)
            Positioned(left: 0, right: 0, bottom: 0, child: Divider(height: 1, color: context.palette.border)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeader old) => true;
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.search, required this.onSearch, required this.filter});
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final NoticeFilter filter;

  static const _types = [
    ('All', 'All', Icons.all_inclusive_rounded),
    ('CompanyEvent', 'Company Event', Icons.business_center_rounded),
    ('General', 'General', Icons.campaign_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(noticeTagsProvider(filter.type)).value ?? const <String>[];
    final ctrl = ref.read(noticeFilterProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: search,
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search announcements, companies…',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.zero,
                fillColor: context.palette.card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          search.clear();
                          onSearch('');
                          FocusScope.of(context).unfocus();
                        },
                      ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (id, label, icon) in _types)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoicePill(
                    label: label,
                    icon: icon,
                    selected: filter.type == id,
                    onTap: () => ctrl.setType(id),
                  ),
                ),
              if (tags.isNotEmpty)
                Container(width: 1, margin: const EdgeInsets.fromLTRB(4, 8, 12, 8), color: context.palette.border),
              for (final tag in tags)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoicePill(
                    label: tag,
                    icon: AppColors.tagIcon(tag),
                    color: AppColors.tagColor(tag),
                    selected: filter.tag == tag,
                    onTap: () => ctrl.setTag(filter.tag == tag ? null : tag),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected, required this.onTap, this.icon, this.color});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.crimson;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected && color == null ? AppColors.brandGradient : null,
          color: selected ? (color == null ? null : c) : context.palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : context.palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : c), const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Timeline --

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.notice, required this.first, required this.last});
  final Announcement notice;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.tagColor(notice.type);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 22, color: first ? Colors.transparent : context.palette.border),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.palette.background, width: 3),
                    boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : context.palette.border)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticeCard(notice: notice),
            ),
          ),
        ],
      ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice, this.compact = false});
  final Announcement notice;
  final bool compact;

  void _open(BuildContext context) {
    final r = notice.redirectUrl;
    if (r != null) {
      openLink(context, r, title: notice.title);
    } else {
      context.push('/notice/${notice.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = notice.plainContent;
    return AppCard(
      onTap: () => _open(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: notice.company.isEmpty ? 'N' : notice.company, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                    if (notice.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notice.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty && !compact) ...[
            const SizedBox(height: 10),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: context.palette.muted, height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: context.palette.muted),
              const SizedBox(width: 4),
              Text(
                Fmt.relative(notice.publishedAt),
                style: context.text.labelSmall?.copyWith(color: context.palette.muted, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (notice.tag != null)
                Flexible(
                  child: Pill(
                    notice.tag!,
                    color: AppColors.tagColor(notice.tag!),
                    icon: AppColors.tagIcon(notice.tag!),
                    dense: true,
                  ),
                ),
              if (notice.attachments.isNotEmpty) ...[
                const SizedBox(width: 6),
                Icon(Icons.attach_file_rounded, size: 16, color: context.palette.muted),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
