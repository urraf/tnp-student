# Releasing an update

Students get updates from **GitHub Releases** of `thenahraf/tnp-student`:

- the app checks `releases/latest` on start (and about twice a day in the background) and offers the update in-app;
- the website's Download button always points at `releases/latest/download/TnP-Student.apk`.

## Every release

1. **Bump the version** in `pubspec.yaml` — both parts must go up:
   ```yaml
   version: 1.2.0+3   # name 1.2.0, build number 3 (was 1.1.0+2)
   ```
2. **Build** (signed with the release key automatically):
   ```bash
   flutter build apk --release
   ```
3. **Create the GitHub release**
   - Tag: `v1.2.0` (must match the version name, with a leading `v`)
   - Title: `TnP Student 1.2.0`
   - Notes: a few bullet points — they're shown in the in-app update sheet
   - Attach `build/app/outputs/flutter-apk/app-release.apk` **renamed to `TnP-Student.apk`**
   - Don't mark it as a pre-release or draft (those are ignored)

   With the GitHub CLI:
   ```bash
   cp build/app/outputs/flutter-apk/app-release.apk /tmp/TnP-Student.apk
   gh release create v1.2.0 /tmp/TnP-Student.apk --title "TnP Student 1.2.0" --notes "- What changed"
   ```

That's it — installed apps see the update within a day (or immediately on next open).

## The signing key (critical)

Android only installs an update over the existing app if it is signed with the **same key**.

- Key: `android/release-keystore.jks`, passwords in `android/key.properties`
- Both are git-ignored — **never commit them**
- **Back them up** (e.g. a password manager + an offline copy). If the key is lost, no existing
  user can update; everyone would have to uninstall and reinstall.

Builds without `key.properties` (e.g. contributors' machines) fall back to the debug key; those
APKs are fine for testing but must never be published as a release.

## Website

The site lives in `docs/` and is served by GitHub Pages:
Settings → Pages → *Deploy from a branch* → `main` / `docs`. It updates itself from the latest
release (version, size, date); edit `docs/assets/app.js` → `CONFIG` if the repo name changes.
