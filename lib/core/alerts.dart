import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'api_client.dart';
import 'theme.dart';
import 'utils.dart';

/// Background "new company / new notice" alerts.
///
/// The TnP backend only supports browser (web-push) notifications, so the app
/// polls instead: Android WorkManager runs [alertsDispatcher] roughly every
/// 15 minutes — also when the app is closed or after a reboot — compares the
/// latest listings with what the student has already seen, and posts local
/// notifications for anything new.
class Alerts {
  Alerts._();

  static const _taskName = 'tnp-check-new-posts';
  static const _uniqueName = 'tnp-check-new-posts-periodic';
  static const _kEnabled = 'alerts_enabled';
  static const _kSeenEvents = 'alerts_seen_events';
  static const _kSeenNotices = 'alerts_seen_notices';
  static const _maxSeen = 300;

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Route to open after a notification tap (consumed by the home shell).
  static final pendingRoute = ValueNotifier<String?>(null);

  // ------------------------------------------------------------- Setup ---

  static Future<void> init() async {
    await _initPlugin(onTap: (r) => pendingRoute.value = r.payload);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      pendingRoute.value = launch!.notificationResponse?.payload;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().initialize(alertsDispatcher);
    }
  }

  static Future<void> _initPlugin({DidReceiveNotificationResponseCallback? onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap,
    );
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? true;
  }

  /// Asks for notification permission (Android 13+) and schedules polling.
  /// Returns false when the user denied the permission.
  static Future<bool> enable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    final granted =
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
    return granted;
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().cancelByUniqueName(_uniqueName);
    }
  }

  /// Called on sign-out: stop polling and forget what was seen.
  static Future<void> reset() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().cancelByUniqueName(_uniqueName);
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSeenEvents);
    await p.remove(_kSeenNotices);
    await _plugin.cancelAll();
  }

  // ------------------------------------------------------ Seen tracking ---

  /// Items shown inside the app count as seen, so they never trigger alerts.
  static Future<void> markEventsSeen(Iterable<String> ids) => _markSeen(_kSeenEvents, ids);
  static Future<void> markNoticesSeen(Iterable<String> ids) => _markSeen(_kSeenNotices, ids);

  static Future<void> _markSeen(String key, Iterable<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final seen = [...?p.getStringList(key)];
    for (final id in ids) {
      if (id.isNotEmpty && !seen.contains(id)) seen.add(id);
    }
    await p.setStringList(key, seen.length > _maxSeen ? seen.sublist(seen.length - _maxSeen) : seen);
  }

  /// Returns ids not seen before and records them. A missing list means this
  /// is the first check: everything becomes the baseline, nothing is "new".
  static Future<List<String>> _takeNew(SharedPreferences p, String key, List<String> ids) async {
    final stored = p.getStringList(key);
    if (stored == null) {
      await p.setStringList(key, ids);
      return const [];
    }
    final fresh = ids.where((id) => id.isNotEmpty && !stored.contains(id)).toList();
    if (fresh.isNotEmpty) {
      final all = [...stored, ...fresh];
      await p.setStringList(key, all.length > _maxSeen ? all.sublist(all.length - _maxSeen) : all);
    }
    return fresh;
  }

  // ------------------------------------------------------------- Check ---

  /// Fetches the latest listings and notifies about new ones.
  /// Returns how many notifications were posted.
  static Future<int> checkNow() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    if (p.getBool(_kEnabled) == false) return 0;

    final token = await TokenStore().read();
    if (token == null || token.isEmpty) return 0;

    final repo = TnpRepository(ApiClient()..token = token);
    final student = await repo.studentMe();
    final results = await Future.wait([
      repo.companyEvents(student: student, start: 0),
      repo.announcements(student: student, start: 0),
    ]);
    final events = results[0] as List<CompanyEvent>;
    final notices = results[1] as List<Announcement>;

    final newEventIds = await _takeNew(p, _kSeenEvents, events.map((e) => e.id).toList());
    final newNoticeIds = await _takeNew(p, _kSeenNotices, notices.map((n) => n.id).toList());

    var posted = 0;
    for (final e in events.where((e) => newEventIds.contains(e.id)).take(5)) {
      final when = e.lastDate == null ? '' : ' · Apply by ${Fmt.dayTime(e.lastDate)}';
      await _show(
        id: e.id,
        title: '🏢 New opening: ${e.companyName.isEmpty ? e.jobTitle : e.companyName}',
        body: '${e.jobTitle}${e.type.isEmpty ? '' : ' (${e.type})'}$when',
        payload: '/job/${e.id}',
        channel: _jobsChannel,
      );
      posted++;
    }
    for (final n in notices.where((n) => newNoticeIds.contains(n.id)).take(5)) {
      final preview = n.plainContent;
      await _show(
        id: n.id,
        title: '📢 ${n.title}',
        body: [if (n.company.isNotEmpty) n.company, if (preview.isNotEmpty) preview].join(' — '),
        payload: n.redirectUrl ?? '/notice/${n.id}',
        channel: _noticesChannel,
      );
      posted++;
    }
    return posted;
  }

  static const _jobsChannel = ('tnp_jobs', 'New company openings', 'When TnP lists a new company or role');
  static const _noticesChannel = ('tnp_notices', 'Announcements', 'New TnP announcements and shortlists');

  static Future<void> _show({
    required String id,
    required String title,
    required String body,
    required String payload,
    required (String, String, String) channel,
  }) {
    final text = body.length > 300 ? '${body.substring(0, 300)}…' : body;
    return _plugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: text,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.$1,
          channel.$2,
          channelDescription: channel.$3,
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.crimson,
          groupKey: 'tnp_updates',
          styleInformation: BigTextStyleInformation(text),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Background entry: plugins need initialising in the worker isolate.
  static Future<void> runInBackground() async {
    await _initPlugin();
    try {
      await checkNow();
    } catch (e) {
      debugPrint('TnP alerts check failed: $e');
    }
  }
}

/// WorkManager entry point (must be a top-level function).
@pragma('vm:entry-point')
void alertsDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await Alerts.runInBackground();
    return true;
  });
}

/// Small helper so UI code can treat posted counts uniformly.
extension AlertsResult on int {
  String get alertsSummary =>
      this == 0 ? 'No new posts right now' : '$this new post${this == 1 ? '' : 's'} — check your notifications';
}

/// Convenience for screens: mark the first page of a feed as seen.
Future<void> markSeenSafely(Future<void> Function() run) async {
  try {
    await run();
  } catch (_) {}
}
