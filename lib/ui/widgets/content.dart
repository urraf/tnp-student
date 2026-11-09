import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/providers.dart';
import 'common.dart';

/// Opens a link: internal portal paths become app routes, PDFs open in the
/// in-app viewer, everything else goes to the browser / dialer / mail app.
Future<void> openLink(BuildContext context, String url, {String? title}) async {
  final u = url.trim();
  if (u.isEmpty) return;

  // Internal web-portal paths, e.g. "/companies/<id>" or "/notices/<id>".
  final internal = RegExp(r'^/?(companies|notices)/([^/?#]+)').firstMatch(u);
  if (internal != null && !u.startsWith('http')) {
    final id = internal.group(2)!;
    context.push(internal.group(1) == 'companies' ? '/job/$id' : '/notice/$id');
    return;
  }

  final uri = Uri.tryParse(u.startsWith('http') || u.contains(':') ? u : 'https://$u');
  if (uri == null) {
    showToast('Invalid link', type: ToastType.error);
    return;
  }
  final isPdf = uri.path.toLowerCase().endsWith('.pdf');
  if (isPdf && (uri.scheme == 'http' || uri.scheme == 'https')) {
    context.push(
      '/pdf',
      extra: PdfArgs(url: uri.toString(), title: title ?? 'Document'),
    );
    return;
  }
  final ok = await launchUrl(
    uri,
    mode: uri.scheme.startsWith('http') ? LaunchMode.externalApplication : LaunchMode.platformDefault,
  );
  if (!ok) showToast('Could not open link', type: ToastType.error);
}

class PdfArgs {
  const PdfArgs({required this.url, required this.title});
  final String url;
  final String title;
}

/// Renders announcement / company content (HTML, Quill Delta or plain text).
class RichContent extends StatelessWidget {
  const RichContent(this.content, {super.key, this.fontSize = 15.5});

  final dynamic content;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final html = RichText2Html.toHtml(content);
    if (html.trim().isEmpty) {
      return Text('No details provided.', style: TextStyle(color: context.palette.muted));
    }
    return SelectionArea(
      child: HtmlWidget(
        html,
        textStyle: context.text.bodyLarge?.copyWith(fontSize: fontSize, height: 1.6),
        onTapUrl: (url) {
          openLink(context, url);
          return true;
        },
        customStylesBuilder: (el) {
          switch (el.localName) {
            case 'a':
              return {'color': '#EE3344', 'text-decoration': 'none', 'font-weight': '600'};
            case 'table':
              return {'border-collapse': 'collapse'};
            case 'td':
            case 'th':
              return {'border': '1px solid #8883', 'padding': '6px'};
            case 'blockquote':
              return {'border-left': '3px solid #EE3344', 'padding-left': '12px', 'margin': '8px 0'};
          }
          return null;
        },
      ),
    );
  }
}

/// Captcha image + input for the IMS-backed flows. The captcha session is
/// held in the API client's cookie jar.
class CaptchaField extends ConsumerWidget {
  const CaptchaField({super.key, required this.controller});
  final TextEditingController controller;

  static Uint8List? _decode(String src) {
    if (!src.startsWith('data:')) return null;
    final comma = src.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(src.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captcha = ref.watch(captchaProvider);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: captcha.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Captcha unavailable — tap refresh',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  data: (src) {
                    final bytes = _decode(src);
                    if (bytes != null) {
                      return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
                    }
                    return Image.network(src, fit: BoxFit.contain);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'New captcha',
              onPressed: () {
                controller.clear();
                ref.invalidate(captchaProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Enter captcha', prefixIcon: Icon(Icons.shield_outlined)),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the captcha shown above' : null,
        ),
      ],
    );
  }
}
