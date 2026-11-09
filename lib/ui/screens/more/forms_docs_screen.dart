import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../data/models.dart';
import '../../../data/repository.dart';
import '../../../state/auth.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';

class FormsDocsScreen extends StatelessWidget {
  const FormsDocsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Forms & Documents'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: const TabBar(
                tabs: [
                  Tab(text: 'Guidelines', height: 40),
                  Tab(text: 'NOC', height: 40),
                  Tab(text: 'Forms', height: 40),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(children: [_GuidelinesTab(), _NocTab(), _FormsTab()]),
      ),
    );
  }
}

// ------------------------------------------------------------ Guidelines --

class _GuidelinesTab extends StatelessWidget {
  const _GuidelinesTab();

  static const _rules = [
    (
      'Download, print and upload in PDF',
      'Download the pre-placement undertaking, print it clearly, get it physically signed by both parents and you, then upload a scanned PDF. It is compulsory for campus placements.',
    ),
    (
      'Clear handwriting & original signatures',
      'Use capital letters in blue/black ink. No overwriting or correction fluid. Only original handwritten signatures are accepted — no digital signatures or typed names.',
    ),
    (
      'Fill all details accurately',
      'Personal and academic details must match official university records. Double-check spellings and numbers.',
    ),
    ('Avoid short forms', 'Write full names and addresses — no abbreviations or initials.'),
    ('Read before signing', 'Signing implies your agreement to the university\'s placement policy.'),
    ('Sign with parents / guardians', 'Both parents (father and mother) must sign along with the student.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          gradient: AppColors.heroGradient,
          onTap: () => openLink(context, AppConfig.placementPolicyUrl, title: 'Placement Policy'),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const IconBadge(Icons.menu_book_rounded, size: 52, gradient: AppColors.brandGradient),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TnP Placement Policy', style: context.text.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Read the official guidelines', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ).entrance(0),
        const SizedBox(height: 22),
        const SectionHeader('Undertaking instructions', icon: Icons.fact_check_rounded),
        for (final (i, r) in _rules.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$1, style: context.text.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          r.$2,
                          style: context.text.bodyMedium?.copyWith(color: context.palette.muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).entrance(i + 1),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Forms --

class _FormsTab extends ConsumerWidget {
  const _FormsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forms = ref.watch(formsProvider);
    final uploads = ref.watch(formUploadsProvider);
    return RefreshIndicator(
      color: AppColors.crimson,
      onRefresh: () async {
        ref.invalidate(formUploadsProvider);
        ref.invalidate(formsProvider);
        await ref.read(formsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionHeader('Available forms', icon: Icons.assignment_rounded),
          AsyncView<List<FormDoc>>(
            value: forms,
            onRetry: () => ref.invalidate(formsProvider),
            loading: const SkeletonList(count: 2, shrinkWrap: true, padding: EdgeInsets.zero),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.assignment_turned_in_outlined, title: 'No active forms');
              }
              final ups = uploads.value ?? const <FormUpload>[];
              return Column(
                children: [
                  for (final (i, f) in list.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FormCard(form: f, uploads: ups.where((u) => u.formId == f.id).toList()).entrance(i),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const SectionHeader('Your uploads', icon: Icons.cloud_done_rounded),
          AsyncView<List<FormUpload>>(
            value: uploads,
            onRetry: () => ref.invalidate(formUploadsProvider),
            loading: const SkeletonList(count: 2, shrinkWrap: true, padding: EdgeInsets.zero),
            data: (list) => list.isEmpty
                ? const EmptyState(icon: Icons.cloud_upload_outlined, title: 'No uploads yet')
                : Column(
                    children: [
                      for (final (i, u) in list.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UploadCard(upload: u).entrance(i),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _formStatusLabel(String s) => switch (s) {
  'ACCEPTED' => 'Accepted',
  'REJECTED' => 'Rejected',
  'PENDING' => 'Under review',
  _ => 'N/A',
};

class _FormCard extends ConsumerWidget {
  const _FormCard({required this.form, required this.uploads});
  final FormDoc form;
  final List<FormUpload> uploads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpload = !uploads.any((u) => u.status == 'ACCEPTED' || u.status == 'PENDING');
    String? status;
    if (uploads.any((u) => u.status == 'ACCEPTED')) {
      status = 'ACCEPTED';
    } else if (uploads.any((u) => u.status == 'PENDING')) {
      status = 'PENDING';
    } else if (uploads.any((u) => u.status == 'REJECTED')) {
      status = 'REJECTED';
    }
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.picture_as_pdf_rounded, color: AppColors.crimson),
              const SizedBox(width: 12),
              Expanded(child: Text(form.name, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (form.isBlocking && canUpload)
                const Pill('Required', color: AppColors.danger, icon: Icons.priority_high_rounded, dense: true),
              if (status != null) StatusPill(_formStatusLabel(status), dense: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: form.fileUrl == null ? null : () => openLink(context, form.fileUrl!, title: form.name),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                ),
              ),
              if (canUpload) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      useSafeArea: true,
                      builder: (_) => _UploadFormSheet(form: form),
                    ),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends ConsumerWidget {
  const _UploadCard({required this.upload});
  final FormUpload upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = upload;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(u.formName, style: context.text.titleSmall)),
              StatusPill(_formStatusLabel(u.status), dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Uploaded ${Fmt.dayTime(u.createdAt)}',
            style: context.text.bodySmall?.copyWith(color: context.palette.muted),
          ),
          if (u.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(10)),
              child: Text(u.message, style: context.text.bodyMedium),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (u.fileUrl != null)
                TextButton.icon(
                  onPressed: () => openLink(context, u.fileUrl!, title: u.formName),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                ),
              if (u.status == 'PENDING')
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Delete record',
                      message: 'This action cannot be undone.',
                      confirmLabel: 'Delete',
                      destructive: true,
                      requiredPhrase: 'DELETE',
                    );
                    if (!ok) return;
                    try {
                      await ref.read(repositoryProvider).deleteFormUpload(u.id);
                      showToast('Upload deleted', type: ToastType.success);
                      ref.invalidate(formUploadsProvider);
                    } catch (e) {
                      toastError(e);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared file picker row used by upload sheets.
class FilePickRow extends StatelessWidget {
  const FilePickRow({super.key, required this.file, required this.onPick, required this.label, this.onClear});
  final PickedUpload? file;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String label;

  @override
  Widget build(BuildContext context) {
    final f = file;
    return Pressable(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: f == null ? context.palette.field : AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: f == null ? context.palette.border : AppColors.success.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              f == null ? Icons.cloud_upload_rounded : Icons.check_circle_rounded,
              color: f == null ? AppColors.crimson : AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f?.name ?? label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  Text(
                    f == null
                        ? 'Tap to choose a file'
                        : '${(f.bytes.length / 1024).toStringAsFixed(0)} KB · tap to change',
                    style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                  ),
                ],
              ),
            ),
            if (f != null && onClear != null) IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          ],
        ),
      ),
    );
  }
}

class _UploadFormSheet extends ConsumerStatefulWidget {
  const _UploadFormSheet({required this.form});
  final FormDoc form;

  @override
  ConsumerState<_UploadFormSheet> createState() => _UploadFormSheetState();
}

class _UploadFormSheetState extends ConsumerState<_UploadFormSheet> {
  PickedUpload? _file;
  bool _confirmed = false;
  bool _uploading = false;
  double _progress = 0;

  Future<void> _pick() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (f == null) return;
    if (!f.name.toLowerCase().endsWith('.pdf')) {
      showToast('Only PDF files are allowed.', type: ToastType.error);
      return;
    }
    final bytes = await f.readAsBytes();
    setState(() => _file = PickedUpload(name: f.name, bytes: bytes));
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      await ref
          .read(repositoryProvider)
          .uploadForm(widget.form.id, _file!, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
      showToast('File uploaded successfully!', type: ToastType.success);
      ref.invalidate(formUploadsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upload: ${widget.form.name}', style: context.text.titleMedium),
          const SizedBox(height: 16),
          FilePickRow(
            file: _file,
            onPick: _pick,
            label: 'Select PDF file',
            onClear: () => setState(() => _file = null),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I confirm the information provided is correct and true as per my knowledge.',
              style: TextStyle(fontSize: 13.5),
            ),
          ),
          if (_uploading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 6),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: 'Upload',
            icon: Icons.cloud_upload_rounded,
            loading: _uploading,
            onPressed: _file != null && _confirmed ? _upload : null,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- NOC --

class _NocTab extends ConsumerStatefulWidget {
  const _NocTab();

  @override
  ConsumerState<_NocTab> createState() => _NocTabState();
}

class _NocTabState extends ConsumerState<_NocTab> {
  final _selected = <String>{};
  bool _deleting = false;

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${_selected.length} NOC request(s)?',
      message: 'Only pending requests can be deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _deleting = true);
    try {
      await ref.read(repositoryProvider).deleteNocs(_selected.toList());
      showToast('Selected NOCs have been deleted', type: ToastType.success);
      _selected.clear();
      ref.invalidate(nocsProvider);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nocs = ref.watch(nocsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: _selected.isEmpty
            ? FloatingActionButton.extended(
                key: const ValueKey('add'),
                heroTag: 'noc-fab',
                backgroundColor: AppColors.crimson,
                foregroundColor: Colors.white,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  useSafeArea: true,
                  builder: (_) => const _NocRequestSheet(),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Request NOC'),
              )
            : FloatingActionButton.extended(
                key: const ValueKey('del'),
                heroTag: 'noc-fab',
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_rounded),
                label: Text('Delete (${_selected.length})'),
              ),
      ),
      body: RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: () => ref.refresh(nocsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: context.isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This No Objection Certificate only grants permission for your training. TnP takes no responsibility '
                      'for attendance, credits, CGPA or schedule conflicts during the training period — you manage your '
                      'academic responsibilities independently.',
                      style: context.text.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AsyncView<List<Noc>>(
              value: nocs,
              onRetry: () => ref.invalidate(nocsProvider),
              loading: const SkeletonList(count: 3, shrinkWrap: true, padding: EdgeInsets.zero),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.verified_outlined,
                      title: 'No NOC requests',
                      subtitle: 'Tap "Request NOC" to apply for an internship NOC.',
                    )
                  : Column(
                      children: [
                        if (list.any((n) => n.pending))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Long-press a pending request to select it for deletion',
                              style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                            ),
                          ),
                        for (final (i, n) in list.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NocCard(
                              noc: n,
                              selected: _selected.contains(n.id),
                              onToggle: n.pending
                                  ? () => setState(
                                      () => _selected.contains(n.id) ? _selected.remove(n.id) : _selected.add(n.id),
                                    )
                                  : null,
                              selectionMode: _selected.isNotEmpty,
                            ).entrance(i),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NocCard extends StatelessWidget {
  const _NocCard({required this.noc, required this.selected, required this.onToggle, required this.selectionMode});
  final Noc noc;
  final bool selected;
  final VoidCallback? onToggle;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final n = noc;
    final color = n.accepted
        ? AppColors.success
        : n.rejected
        ? AppColors.danger
        : AppColors.warning;
    return Pressable(
      onTap: selectionMode ? onToggle : null,
      onLongPress: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.danger.withValues(alpha: 0.07) : context.palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.danger : context.palette.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectionMode && n.pending) ...[
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: selected ? AppColors.danger : context.palette.muted,
                  ),
                  const SizedBox(width: 10),
                ],
                InitialsAvatar(name: n.company, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.company, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${n.city}, ${n.state}',
                        style: context.text.bodySmall?.copyWith(color: context.palette.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Pill(n.statusLabel, color: color, dense: true),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill('${n.start} → ${n.end}', icon: Icons.date_range_rounded, dense: true),
                if (n.source.isNotEmpty) Pill(n.source, icon: Icons.hub_rounded, dense: true, color: AppColors.indigo),
                if (n.pinCode.isNotEmpty) Pill(n.pinCode, icon: Icons.pin_drop_rounded, dense: true),
              ],
            ),
            if (n.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(n.address, style: context.text.bodySmall?.copyWith(color: context.palette.muted)),
            ],
            if (n.message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(10)),
                child: Text(n.message, style: context.text.bodyMedium),
              ),
            ],
            if (n.nocLink != null) ...[
              const SizedBox(height: 12),
              GradientButton(
                label: 'Download NOC',
                icon: Icons.download_rounded,
                height: 46,
                onPressed: () => openLink(context, n.nocLink!, title: 'NOC - ${n.company}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NocRequestSheet extends ConsumerStatefulWidget {
  const _NocRequestSheet();

  @override
  ConsumerState<_NocRequestSheet> createState() => _NocRequestSheetState();
}

class _NocRequestSheetState extends ConsumerState<_NocRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in ['company', 'address', 'city', 'state', 'pinCode']) k: TextEditingController(),
  };
  DateTime? _start;
  DateTime? _end;
  String? _source;
  PickedUpload? _proof;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? (start ? now : (_start ?? now)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: start ? 'Internship start date' : 'Internship end date',
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _pickProof() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'doc', 'docx']);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _proof = PickedUpload(name: f.name, bytes: bytes));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_start == null || _end == null) {
      showToast('Pick start and end dates', type: ToastType.error);
      return;
    }
    if (_end!.isBefore(_start!)) {
      showToast('End date must be after the start date', type: ToastType.error);
      return;
    }
    if (_proof == null) {
      showToast('Please upload a proof file', type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      final start = _iso(_start!), end = _iso(_end!);
      await ref.read(repositoryProvider).applyNoc({
        for (final e in _c.entries) e.key: e.value.text.trim(),
        'start': start,
        'end': end,
        'startDate': start,
        'endDate': end,
        'source': _source!,
      }, _proof!);
      showToast('NOC requested successfully', type: ToastType.success);
      ref.invalidate(nocsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(String key, String label, IconData icon, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[key],
      keyboardType: type,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
    ),
  );

  Widget _dateTile(String label, DateTime? d, bool start) => Expanded(
    child: Pressable(
      onTap: () => _pickDate(start),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.palette.field, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelSmall?.copyWith(color: context.palette.muted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 18, color: d == null ? context.palette.muted : AppColors.crimson),
                const SizedBox(width: 6),
                Text(d == null ? 'Select' : Fmt.day(d), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Request NOC', style: context.text.titleLarge),
              const SizedBox(height: 16),
              _field('company', 'Company', Icons.business_rounded),
              _field('address', 'Address', Icons.location_on_rounded),
              Row(
                children: [
                  Expanded(child: _field('city', 'City', Icons.location_city_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('state', 'State', Icons.map_rounded)),
                ],
              ),
              _field('pinCode', 'PIN code', Icons.pin_drop_rounded, type: TextInputType.number),
              Row(
                children: [
                  _dateTile('Start date', _start, true),
                  const SizedBox(width: 10),
                  _dateTile('End date', _end, false),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _source,
                borderRadius: BorderRadius.circular(16),
                decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.hub_rounded)),
                items: const [
                  DropdownMenuItem(value: 'On_Campus', child: Text('On Campus')),
                  DropdownMenuItem(value: 'Off_Campus', child: Text('Off Campus')),
                ],
                onChanged: (v) => setState(() => _source = v),
                validator: (v) => v == null ? 'Select source' : null,
              ),
              const SizedBox(height: 12),
              FilePickRow(
                file: _proof,
                onPick: _pickProof,
                label: 'Proof of internship (offer letter or resume)',
                onClear: () => setState(() => _proof = null),
              ),
              const SizedBox(height: 18),
              GradientButton(label: 'Request NOC', icon: Icons.send_rounded, loading: _submitting, onPressed: _submit),
            ],
          ).animate().fadeIn(duration: 250.ms),
        ),
      ),
    );
  }
}
