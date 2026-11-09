import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';
import 'notices_screen.dart';

class NoticeDetailScreen extends ConsumerWidget {
  const NoticeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(noticeDetailProvider(id));
    return Scaffold(
      body: AsyncView<NoticeDetail>(
        value: detail,
        onRetry: () => ref.invalidate(noticeDetailProvider(id)),
        loading: const _DetailSkeleton(),
        data: (d) => RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: () => ref.refresh(noticeDetailProvider(id).future),
          child: _Body(detail: d),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});
  final NoticeDetail detail;

  @override
  Widget build(BuildContext context) {
    final n = detail.notice;
    final typeColor = AppColors.tagColor(n.type);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 210,
          backgroundColor: AppColors.navyDeep,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            IconButton(
              tooltip: 'Copy text',
              icon: const Icon(Icons.copy_all_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${n.title}\n\n${n.plainContent}'));
                showToast('Copied to clipboard', type: ToastType.success);
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Stack(
                children: [
                  Positioned(
                    right: -60,
                    top: -40,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [typeColor.withValues(alpha: 0.5), Colors.transparent]),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Pill(
                                n.isCompanyEvent ? 'Company Event' : 'General Notice',
                                color: typeColor,
                                filled: true,
                                icon: AppColors.tagIcon(n.type),
                              ),
                              if (n.tag != null) Pill(n.tag!, color: Colors.white, icon: AppColors.tagIcon(n.tag!)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            n.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleLarge?.copyWith(color: Colors.white, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    InfoRow(icon: Icons.event_rounded, label: 'Published', value: Fmt.dayTime(n.publishedAt)),
                    if (n.company.isNotEmpty) InfoRow(icon: Icons.business_rounded, label: 'Company', value: n.company),
                    if (n.degrees.isNotEmpty)
                      InfoRow(
                        icon: Icons.school_rounded,
                        label: 'Degrees',
                        value: n.degrees.length >= 7 ? 'All degrees' : n.degrees.join(', '),
                      ),
                    if (n.batches.isNotEmpty)
                      InfoRow(icon: Icons.groups_rounded, label: 'Batches', value: n.batches.join(', ')),
                  ],
                ),
              ).entrance(0),
              const SizedBox(height: 14),
              AppCard(padding: const EdgeInsets.all(18), child: RichContent(n.content)).entrance(1),
              if (n.attachments.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  'Attachments',
                  subtitle: '${n.attachments.length} file(s)',
                  icon: Icons.attach_file_rounded,
                ),
                for (final (i, a) in n.attachments.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AttachmentTile(attachment: a).entrance(i + 2),
                  ),
              ],
              if (detail.company != null) ...[
                const SizedBox(height: 22),
                _CompanyCard(company: detail.company!).entrance(3),
              ],
              if (detail.related.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  'Related notices',
                  subtitle: '${detail.related.length} more from this event',
                  icon: Icons.layers_rounded,
                ),
                for (final (i, r) in detail.related.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NoticeCard(notice: r).entrance(i + 4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment});
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final size = Fmt.fileSizeKb(a.size);
    return AppCard(
      onTap: () => openLink(context, a.url, title: a.name),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: a.isPdf ? AppColors.brandGradient : null,
              color: a.isPdf ? null : AppColors.info,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              a.ext.length > 4 ? a.ext.substring(0, 4) : a.ext,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                if (size.isNotEmpty) Text(size, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
              ],
            ),
          ),
          Icon(a.isPdf ? Icons.visibility_rounded : Icons.download_rounded, color: AppColors.crimson),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});
  final CompanyInfo company;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompanyLogo(name: company.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company information',
                      style: context.text.labelMedium?.copyWith(color: context.palette.muted),
                    ),
                    Text(company.name, style: context.text.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          if (str(company.info) != null || company.info is List) ...[
            const SizedBox(height: 12),
            RichContent(company.info, fontSize: 14),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (company.category != null) Pill(company.category!, icon: Icons.sell_rounded, color: AppColors.indigo),
              if (company.turnover != null)
                Pill('Turnover: ${company.turnover}', icon: Icons.trending_up_rounded, color: AppColors.success),
              if (company.eventCount > 0)
                Pill(
                  '${company.eventCount} event${company.eventCount > 1 ? 's' : ''}',
                  icon: Icons.event_rounded,
                  color: AppColors.info,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 210 + MediaQuery.paddingOf(context).top,
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
          ),
        ),
        Expanded(
          child: Skeleton(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SkeletonBox(height: 140, radius: 20),
                SizedBox(height: 14),
                SkeletonBox(height: 280, radius: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
