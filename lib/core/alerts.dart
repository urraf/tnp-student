import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'api_client.dart';
import 'theme.dart';
import 'updater.dart';
import 'utils.dart';

/// Background "new company / new notice" alerts.
///
/// The TnP backend only supports browser (web-push) notifications, so the app
/// polls. Plain background jobs get parked by Android for apps that aren't
/// opened often (that's why alerts used to appear only when the app opened),
/// so checks are driven by an **exact wake-up alarm** that fires even in Doze
/// and re-arms itself every [interval]; WorkManager stays as a backup.
class Alerts {
  Alerts._();

  /// 15 minutes in real builds; `--dart-define=ALERT_MINUTES=2` speeds up testing.
  static const interval = Duration(minutes: int.fromEnvironment('ALERT_MINUTES', defaultValue: 15));
  static const _alarmId = 4207;
  static const _taskName = 'tnp-check-new-posts';
  static const _uniqueName = 'tnp-check-new-posts-periodic';
  static const _kEnabled = 'alerts_enabled';
  static const _kSeenEvents = 'alerts_seen_events';
  static const _kSeenNotices = 'alerts_seen_notices';
  static const _kLastRun = 'alerts_last_run_ms';
  static const _kLastUpdateCheck = 'alerts_last_update_check_ms';
  static const _kNotifiedVersion = 'alerts_notified_update_version';
  static const _maxSeen = 300;

  /// Payload of the "update available" notification.
  static const updatePayload = 'app-update';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Route to open after a notification tap (consumed by the home shell).
  static final pendingRoute = ValueNotifier<String?>(null);

  // --------------------------------------------------------------- Channels --
  //
  // Android fixes a channel's sound when it is first created, so the custom
  // tunes need new channel ids; the old silent-default channels are removed.

  static final _jobs = _Channel(
    'tnp_openings_v2',
    'New company openings',
    'Rings when TnP lists a new company or role',
    sound: 'tnp_new_company',
    vibration: Int64List.fromList([0, 220, 120, 220, 120, 420]),
  );
  static final _notices = _Channel(
    'tnp_announcements_v2',
    'Announcements',
    'New TnP announcements and shortlists',
    sound: 'tnp_new_notice',
    vibration: Int64List.fromList([0, 180, 100, 180]),
  );
  static final _updates = _Channel('tnp_app_updates', 'App updates', 'A new version of TnP Student is available');
  static const _legacyChannels = ['tnp_jobs', 'tnp_notices'];

  // ------------------------------------------------------------------ Setup --

  static Future<void> init() async {
    await _initPlugin(onTap: (r) => pendingRoute.value = r.payload);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      pendingRoute.value = launch!.notificationResponse?.payload;
    }
    if (_android) {
      await Workmanager().initialize(alertsDispatcher);
      await AndroidAlarmManager.initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final id in _legacyChannels) {
        try {
          await android?.deleteNotificationChannel(channelId: id);
        } catch (_) {}
      }
      for (final c in [_jobs, _notices, _updates]) {
        await android?.createNotificationChannel(c.toAndroid());
      }
    }
  }

  static Future<void> _initPlugin({DidReceiveNotificationResponseCallback? onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_tnp'),
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

  /// Asks for notification permission (Android 13+) and starts the checks.
  /// Returns false when the user denied the permission.
  static Future<bool> enable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    final granted =
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
    if (_android) {
      await scheduleNextAlarm();
      // Backup path: if the OEM blocks alarms, WorkManager still runs eventually.
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: interval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
    return granted;
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
    if (_android) {
      await AndroidAlarmManager.cancel(_alarmId);
      await Workmanager().cancelByUniqueName(_uniqueName);
    }
  }

  /// Called on sign-out: stop polling and forget what was seen.
  static Future<void> reset() async {
    if (_android) {
      await AndroidAlarmManager.cancel(_alarmId);
      await Workmanager().cancelByUniqueName(_uniqueName);
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSeenEvents);
    await p.remove(_kSeenNotices);
    await _plugin.cancelAll();
  }

  /// Arms the next exact wake-up alarm (replaces any pending one).
  /// Works from the UI isolate and from inside the alarm callback.
  static Future<void> scheduleNextAlarm() async {
    if (!_android) return;
    try {
      await AndroidAlarmManager.oneShot(
        interval,
        _alarmId,
        alertsAlarmCallback,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (e) {
      // Exact alarms not permitted on this device: fall back to an inexact one.
      debugPrint('Exact alarm unavailable ($e); using inexact alarm');
      try {
        await AndroidAlarmManager.oneShot(
          interval,
          _alarmId,
          alertsAlarmCallback,
          allowWhileIdle: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------- Seen tracking --

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

  // ------------------------------------------------------------------ Check --

  /// Fetches the latest listings and notifies about new ones.
  /// [background] runs skip if another check started moments ago (the alarm
  /// and the WorkManager backup can fire close together).
  /// Returns how many notifications were posted.
  static Future<int> checkNow({bool background = false}) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    if (p.getBool(_kEnabled) == false) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (background && now - (p.getInt(_kLastRun) ?? 0) < const Duration(minutes: 4).inMilliseconds) return 0;
    await p.setInt(_kLastRun, now);

    var posted = 0;
    final token = await TokenStore().read();
    if (token != null && token.isNotEmpty) posted += await _checkTnp(p, token);
    if (background) posted += await _checkForUpdate(p);
    return posted;
  }

  static Future<int> _checkTnp(SharedPreferences p, String token) async {
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
      final pay = e.stipend.isEmpty ? '' : ' · ${e.stipend}';
      await _show(
        id: e.id,
        title: '🏢 New company: ${e.companyName.isEmpty ? e.jobTitle : e.companyName}',
        body: '${e.jobTitle}${e.type.isEmpty ? '' : ' (${e.type})'}$pay$when',
        payload: '/job/${e.id}',
        channel: _jobs,
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
        channel: _notices,
      );
      posted++;
    }
    return posted;
  }

  /// At most twice a day: notify once per new version on GitHub Releases.
  static Future<int> _checkForUpdate(SharedPreferences p) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (p.getInt(_kLastUpdateCheck) ?? 0) < const Duration(hours: 12).inMilliseconds) return 0;
    await p.setInt(_kLastUpdateCheck, now);
    try {
      final update = await Updater.check();
      if (update == null || p.getString(_kNotifiedVersion) == update.version) return 0;
      await p.setString(_kNotifiedVersion, update.version);
      await _show(
        id: 'update-${update.version}',
        title: '⬆️ TnP Student ${update.version} is available',
        body: update.notes.isEmpty ? 'Tap to update the app.' : update.notes,
        payload: updatePayload,
        channel: _updates,
      );
      return 1;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _show({
    required String id,
    required String title,
    required String body,
    required String payload,
    required _Channel channel,
  }) {
    final text = body.length > 300 ? '${body.substring(0, 300)}…' : body;
    return _plugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: text,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: channel.details(text),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  /// Background entry: plugins need initialising in the worker isolate.
  static Future<void> runInBackground() async {
    await _initPlugin();
    try {
      await checkNow(background: true);
    } catch (e) {
      debugPrint('TnP alerts check failed: $e');
    }
  }
}

class _Channel {
  _Channel(this.id, this.name, this.description, {this.sound, this.vibration});

  final String id;
  final String name;
  final String description;
  final String? sound;
  final Int64List? vibration;

  AndroidNotificationChannel toAndroid() => AndroidNotificationChannel(
    id,
    name,
    description: description,
    importance: Importance.high,
    playSound: true,
    sound: sound == null ? null : RawResourceAndroidNotificationSound(sound),
    enableVibration: true,
    vibrationPattern: vibration,
    enableLights: true,
    ledColor: AppColors.crimson,
  );

  AndroidNotificationDetails details(String text) => AndroidNotificationDetails(
    id,
    name,
    channelDescription: description,
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_tnp',
    color: AppColors.crimson,
    playSound: true,
    sound: sound == null ? null : RawResourceAndroidNotificationSound(sound),
    enableVibration: true,
    vibrationPattern: vibration,
    enableLights: true,
    ledColor: AppColors.crimson,
    ledOnMs: 600,
    ledOffMs: 1800,
    category: AndroidNotificationCategory.recommendation,
    visibility: NotificationVisibility.public,
    ticker: text,
    groupKey: 'tnp_updates',
    styleInformation: BigTextStyleInformation(text),
  );
}

/// Exact-alarm entry point (must be top-level). Re-arms first so a failed
/// check never breaks the chain, then runs the check.
@pragma('vm:entry-point')
Future<void> alertsAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  await p.reload();
  if (p.getBool(Alerts._kEnabled) == false) return;
  await Alerts.scheduleNextAlarm();
  await Alerts.runInBackground();
}

/// WorkManager entry point (backup path; must be top-level).
@pragma('vm:entry-point')
void alertsDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await Alerts.runInBackground();
    // Also revive the alarm chain in case the OEM cleared it.
    await Alerts.scheduleNextAlarm();
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
