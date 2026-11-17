# TnP Student

Unofficial, open-source Android app for NSUT students on top of the Training & Placement portal
(`api.tnpnsut.in`, the same backend as student.tnpnsut.in).

- **New-company alerts** with their own chime — checks every 15 minutes even when the app is closed
  (exact wake-up alarms that survive Doze and reboots, WorkManager as backup)
- One-tap apply with eligibility check, applications, announcements with search & tags
- Profile, CGPA sync, drop-subject planner, resumes, hall card (QR + PDF), forms & NOC, feedback
- **Self-updating** from GitHub Releases

Website: `docs/` (GitHub Pages) · Releasing updates: [RELEASING.md](RELEASING.md)

Developed by **Farhan** · [nahraf.tech](https://www.nahraf.tech)

## Run

```bash
flutter run                                   # real portal
flutter run --dart-define=DEMO=true           # offline sample data, no account needed
flutter run --dart-define=DEMO=true --dart-define=ALERT_MINUTES=2   # faster alert testing
flutter test
flutter build apk --release                   # signed with android/key.properties (see RELEASING.md)
```

## Layout

```
lib/core/     config, theme, API client, router, alerts (background checks), updater, system bridge
lib/data/     models + repository (one method per portal endpoint)
lib/state/    auth and feeds (Riverpod)
lib/ui/       screens and widgets
android/app/src/main/kotlin/…/MainActivity.kt   battery/autostart/installer bridge
docs/         download website
```

Not affiliated with NSUT or its Training & Placement cell.
