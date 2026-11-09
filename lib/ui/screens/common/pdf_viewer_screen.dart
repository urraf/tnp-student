import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../state/auth.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';

/// In-app PDF viewer with download progress, share and open-in-browser.
class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({super.key, required this.args});
  final PdfArgs args;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final _cancel = CancelToken();
  Uint8List? _bytes;
  Object? _error;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final bytes = await ref
          .read(repositoryProvider)
          .download(
            widget.args.url,
            cancel: _cancel,
            onProgress: (p) => mounted ? setState(() => _progress = p) : null,
          );
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted && !_cancel.isCancelled) setState(() => _error = e);
    }
  }

  String get _fileName {
    final seg = Uri.tryParse(widget.args.url)?.pathSegments;
    final last = (seg == null || seg.isEmpty) ? 'document.pdf' : Uri.decodeComponent(seg.last);
    return last.toLowerCase().endsWith('.pdf') ? last : '$last.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final Widget body;
    if (bytes != null) {
      body = PdfPreview(
        key: const ValueKey('pdf'),
        build: (_) async => bytes,
        useActions: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 900,
        pdfFileName: _fileName,
        scrollViewDecoration: BoxDecoration(color: context.palette.background),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 16, offset: const Offset(0, 6))],
        ),
        onError: (ctx, e) => const ErrorState(error: 'This file could not be displayed. Try "Open in browser".'),
      );
    } else if (_error != null) {
      body = ErrorState(key: const ValueKey('err'), error: _error!, onRetry: _load);
    } else {
      body = Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: context.palette.subtle,
                  ),
                  Center(
                    child: Text(
                      _progress == 0 ? '' : '${(_progress * 100).round()}%',
                      style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Downloading document…', style: TextStyle(color: context.palette.muted)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(Uri.parse(widget.args.url), mode: LaunchMode.externalApplication),
          ),
          if (bytes != null)
            IconButton(
              tooltip: 'Share / save',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => Printing.sharePdf(bytes: bytes, filename: _fileName),
            ),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: body),
    );
  }
}
