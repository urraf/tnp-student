import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../state/auth.dart';
import '../../widgets/common.dart';
import '../../widgets/content.dart';

/// In-app PDF viewer with download progress, pinch/double-tap zoom, share and
/// open-in-browser.
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
      body = _ZoomablePdf(
        key: const ValueKey('pdf'),
        bytes: bytes,
        sourceName: widget.args.url,
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

/// Continuous-scroll PDF with pinch-to-zoom (pages re-render sharply at every
/// zoom level), double-tap to zoom in/out, a page counter and a scroll thumb.
class _ZoomablePdf extends StatefulWidget {
  const _ZoomablePdf({super.key, required this.bytes, required this.sourceName});
  final Uint8List bytes;
  final String sourceName;

  @override
  State<_ZoomablePdf> createState() => _ZoomablePdfState();
}

class _ZoomablePdfState extends State<_ZoomablePdf> {
  final _controller = PdfViewerController();
  final _page = ValueNotifier<int?>(null);
  double? _fitZoom; // zoom level when the document first fits the screen

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  bool _onTap(BuildContext context, PdfViewerController c, PdfViewerGeneralTapHandlerDetails d) {
    if (d.type != PdfViewerGeneralTapType.doubleTap || !c.isReady) return false;
    final fit = _fitZoom ?? c.currentZoom;
    final zoomedIn = c.currentZoom > fit * 1.15;
    c.zoomOnLocalPosition(
      localPosition: d.localPosition,
      newZoom: zoomedIn ? fit : (fit * 2.5).clamp(fit, c.maxScale),
      duration: const Duration(milliseconds: 260),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PdfViewer.data(
      widget.bytes,
      sourceName: widget.sourceName,
      controller: _controller,
      params: PdfViewerParams(
        margin: 12,
        backgroundColor: palette.background,
        pageDropShadow: BoxShadow(color: palette.shadow, blurRadius: 14, offset: const Offset(0, 5)),
        onViewerReady: (doc, c) {
          _fitZoom = c.currentZoom;
          _page.value = c.pageNumber ?? 1;
        },
        onPageChanged: (n) => _page.value = n,
        onGeneralTap: _onTap,
        errorBannerBuilder: (ctx, e, st, ref) =>
            const ErrorState(error: 'This file could not be displayed. Try "Open in browser".'),
        loadingBannerBuilder: (ctx, done, total) => const Center(child: CircularProgressIndicator()),
        viewerOverlayBuilder: (ctx, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _controller,
            orientation: ScrollbarOrientation.right,
            thumbSize: const Size(44, 28),
            thumbBuilder: (ctx, thumbSize, pageNumber, c) => DecoratedBox(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 8)],
              ),
              child: Center(
                child: Text(
                  '${pageNumber ?? ''}',
                  style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: Center(
              child: ValueListenableBuilder<int?>(
                valueListenable: _page,
                builder: (ctx, page, _) {
                  if (page == null || !_controller.isReady) return const SizedBox.shrink();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Text(
                        '$page / ${_controller.pageCount}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
