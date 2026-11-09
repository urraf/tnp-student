import 'dart:convert';

import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Loose JSON helpers. The Strapi v3 backend is schemaless-ish (MongoDB), so
// every field is read defensively.
// ---------------------------------------------------------------------------

typedef Json = Map<String, dynamic>;

Json asJson(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

List<Json> asJsonList(dynamic v) {
  if (v is List) return v.whereType<Map>().map(asJson).toList();
  return const [];
}

String? str(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v;
  if (v is num || v is bool) return v.toString();
  return null;
}

String strOr(dynamic v, [String fallback = '']) => str(v) ?? fallback;

double? dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int? integer(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt();
  return null;
}

bool boolean(dynamic v) => v == true || v == 'true';

/// Strapi v3 on Mongo exposes both `id` and `_id`.
String idOf(dynamic v) {
  if (v is String) return v;
  final j = asJson(v);
  return strOr(j['id'] ?? j['_id']);
}

DateTime? date(dynamic v) {
  final s = str(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

List<String> strList(dynamic v) {
  if (v is List) return v.map(str).whereType<String>().toList();
  if (v is String && v.trim().isNotEmpty) return [v];
  return const [];
}

/// Formats a numeric display value; hides "-1" sentinel the backend uses.
String displayNum(dynamic v, {String empty = '—'}) {
  final s = str(v);
  if (s == null || s == '-1') return empty;
  return s;
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

class Fmt {
  Fmt._();
  static final _day = DateFormat('d MMM yyyy');
  static final _dayTime = DateFormat('d MMM yyyy, h:mm a');
  static final _time = DateFormat('h:mm a');
  static final _long = DateFormat('d MMMM yyyy');

  static String day(DateTime? d) => d == null ? '—' : _day.format(d);
  static String dayTime(DateTime? d) => d == null ? '—' : _dayTime.format(d);
  static String time(DateTime? d) => d == null ? '' : _time.format(d);
  static String long(DateTime? d) => d == null ? '—' : _long.format(d);

  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.isNegative) return day(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return day(d);
  }

  /// "Closes in 2d 4h" style countdown for deadlines.
  static String countdown(DateTime? d) {
    if (d == null) return '';
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'Closed';
    if (diff.inDays >= 1) return '${diff.inDays}d ${diff.inHours % 24}h left';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    return '${diff.inMinutes}m left';
  }

  static String fileSizeKb(dynamic sizeKb) {
    final kb = dbl(sizeKb);
    if (kb == null) return '';
    if (kb >= 1024) return '${(kb / 1024).toStringAsFixed(2)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }
}

String initials(String? name, {int max = 2}) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return 'N';
  final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  return parts.take(max).map((e) => e[0].toUpperCase()).join();
}

// ---------------------------------------------------------------------------
// Rich content: the backend stores announcement bodies as HTML, as Quill
// Delta JSON, or as plain text. Normalise everything to HTML.
// ---------------------------------------------------------------------------

class RichText2Html {
  RichText2Html._();

  static String toHtml(dynamic content) {
    if (content == null) return '';
    final delta = _asDelta(content);
    if (delta != null) return _deltaToHtml(delta);
    final s = content is String ? content : jsonEncode(content);
    if (s.contains('<') && s.contains('>')) return s;
    return _escape(s).replaceAll('\n', '<br/>');
  }

  static String toPlain(dynamic content) {
    final html = toHtml(content);
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</(p|div|li|h\d)>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<Json>? _asDelta(dynamic content) {
    dynamic parsed = content;
    if (content is String) {
      final t = content.trim();
      if (!(t.startsWith('[') || t.startsWith('{'))) return null;
      try {
        parsed = jsonDecode(t);
      } catch (_) {
        return null;
      }
    }
    if (parsed is Map && parsed['ops'] is List) parsed = parsed['ops'];
    if (parsed is List &&
        parsed.isNotEmpty &&
        parsed.any((e) => e is Map && (e.containsKey('insert') || e.containsKey('attributes')))) {
      return asJsonList(parsed);
    }
    return null;
  }

  static String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _inline(String text, Json attrs) {
    var t = _escape(text);
    if (attrs['bold'] == true) t = '<b>$t</b>';
    if (attrs['italic'] == true) t = '<i>$t</i>';
    if (attrs['underline'] == true) t = '<u>$t</u>';
    if (attrs['strike'] == true) t = '<s>$t</s>';
    if (attrs['code'] == true) t = '<code>$t</code>';
    final color = str(attrs['color']);
    if (color != null) t = '<span style="color:$color">$t</span>';
    final link = str(attrs['link']);
    if (link != null) t = '<a href="$link">$t</a>';
    return t;
  }

  /// Minimal Quill Delta → HTML (paragraphs, headers, lists, inline marks).
  static String _deltaToHtml(List<Json> ops) {
    final out = StringBuffer();
    var line = StringBuffer();
    String? openList;

    void closeList() {
      if (openList != null) {
        out.write('</$openList>');
        openList = null;
      }
    }

    void flushLine(Json blockAttrs) {
      final content = line.isEmpty ? '<br/>' : line.toString();
      final list = str(blockAttrs['list']);
      final header = integer(blockAttrs['header']);
      if (list != null) {
        final tag = list == 'ordered' ? 'ol' : 'ul';
        if (openList != tag) {
          closeList();
          out.write('<$tag>');
          openList = tag;
        }
        out.write('<li>$content</li>');
      } else {
        closeList();
        if (header != null && header >= 1 && header <= 6) {
          out.write('<h$header>$content</h$header>');
        } else if (blockAttrs['blockquote'] == true) {
          out.write('<blockquote>$content</blockquote>');
        } else {
          out.write('<p>$content</p>');
        }
      }
      line = StringBuffer();
    }

    for (final op in ops) {
      final insert = op['insert'];
      final attrs = asJson(op['attributes']);
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) line.write(_inline(parts[i], attrs));
          if (i < parts.length - 1) flushLine(attrs);
        }
      } else if (insert is Map && insert['image'] != null) {
        line.write('<img src="${insert['image']}"/>');
      }
    }
    if (line.isNotEmpty) flushLine(const {});
    closeList();
    return out.toString();
  }
}
