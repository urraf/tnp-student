import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'system.dart';

/// A newer version published on GitHub Releases.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.sizeBytes,
    this.publishedAt,
  });

  final String version;
  final String notes;
  final String apkUrl;
  final int sizeBytes;
  final DateTime? publishedAt;

  String get sizeLabel => sizeBytes <= 0 ? '' : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The student must allow "Install unknown apps" for TnP Student once.
class InstallPermissionNeeded implements Exception {
  const InstallPermissionNeeded();
  @override
  String toString() => 'Allow TnP Student to install updates, then tap Install again.';
}

/// Self-update for a sideloaded app: checks GitHub Releases, downloads the
/// new APK and hands it to Android's installer. Updates only install over the
/// existing app when signed with the same release key (see android/key.properties).
class Updater {
  Updater._();

  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// Compares dotted versions numerically: 1.10.0 > 1.9.3. Ignores a leading
  /// "v" and any "+build" / "-suffix".
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[+\-]'))
        .first
        .split('.')
        .map((x) => int.tryParse(x) ?? 0)
        .toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Latest release if it is newer than the installed app, otherwise null.
  static Future<AppUpdate?> check({Dio? dio}) async {
    final client =
        dio ??
        Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
    final Response<dynamic> res;
    try {
      res = await client.get<dynamic>(
        AppConfig.latestReleaseApi,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } on DioException {
      return null; // offline: just try again later
    }
    if (res.statusCode != 200 || res.data is! Map) return null; // no release published yet
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['draft'] == true || data['prerelease'] == true) return null;

    final latest = '${data['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^[vV]'), '');
    if (latest.isEmpty || compareVersions(latest, await currentVersion()) <= 0) return null;

    final assets = ((data['assets'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final apk = assets.firstWhere(
      (a) => a['name'] == AppConfig.apkAssetName,
      orElse: () => assets.firstWhere((a) => '${a['name']}'.toLowerCase().endsWith('.apk'), orElse: () => const {}),
    );
    final url = apk['browser_download_url'] as String?;
    if (url == null) return null;

    return AppUpdate(
      version: latest,
      notes: '${data['body'] ?? ''}'.trim(),
      apkUrl: url,
      sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse('${data['published_at'] ?? ''}'),
    );
  }

  /// Downloads the update APK into cache/updates (shared with the installer).
  static Future<String> download(AppUpdate u, {void Function(double)? onProgress, CancelToken? cancel}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}TnP-Student-${u.version}.apk';
    await Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(minutes: 5)),
    ).download(
      u.apkUrl,
      path,
      cancelToken: cancel,
      onReceiveProgress: onProgress == null
          ? null
          : (r, t) {
              final total = t > 0 ? t : u.sizeBytes;
              if (total > 0) onProgress(r / total);
            },
    );
    return path;
  }

  /// Opens Android's installer for [path]. Throws [InstallPermissionNeeded]
  /// (after opening the right settings page) the first time.
  static Future<void> install(String path) async {
    if (!await SystemBridge.canInstallPackages()) {
      await SystemBridge.openInstallPermissionSettings();
      throw const InstallPermissionNeeded();
    }
    if (!await SystemBridge.installApk(path)) {
      throw Exception('Could not open the installer. Download the update from ${AppConfig.websiteUrl}');
    }
  }
}
