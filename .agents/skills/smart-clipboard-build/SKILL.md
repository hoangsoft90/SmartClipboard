# Smart Clipboard — Build Debug APK on GitHub Actions

## Overview
Build debug APK for Smart Clipboard Flutter app using GitHub Actions with gradle directly (no EAS, no local build).

## Trigger Keywords
- "build apk", "build debug", "build release", "GH Actions build"
- "push and build", "deploy to GH Actions"
- "smart clipboard build"

## Repository Info
- **Repo**: `https://github.com/hoangsoft90/SmartClipboard`
- **Branch**: `main`
- **Workflow**: `.github/workflows/build-android.yml`

## Build Steps (GH Actions)

### 1. Push code to main branch
```bash
git add -A
git commit -m "your message"
git push origin main
```

### 2. Workflow auto-triggers on push to main
The workflow `.github/workflows/build-android.yml` will:
- Checkout code
- Setup Java 17 + Flutter 3.24.0
- Save custom Android files
- Generate Flutter platform scaffolding (`flutter create`)
- Restore custom Android files
- Install dependencies
- Build debug APK using gradle directly

### 3. Check build status
```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"
```

### 4. Download APK artifact
After build completes:
- Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
- Click on the workflow run
- Download `smart-clipboard-debug-apk` artifact

## Important Notes

### DO NOT build locally
- User explicitly said: "Tuyệt đối ko build apk trên local"
- Always use GitHub Actions for builds
- This ensures consistent builds and avoids local environment issues

### Gradle directly (not Flutter build)
The workflow uses gradle directly for more control:
```bash
cd android
chmod +x gradlew
./gradlew assembleDebug --stacktrace
```

### Key Workflow Features
- Java 17 (temurin)
- Flutter 3.24.0 (stable)
- Platform scaffolding via `flutter create`
- Save/restore custom Android files
- Network security config for HTTP cleartext
- Adaptive icons (vector XML)
- Upload artifacts (debug + release APK)

### Common Build Issues & Fixes

1. **"Could not resolve..."** - Gradle dependency issue
   - Fix: Check internet connectivity in workflow
   - Fix: Add `--stacktrace` for more details

2. **"SDK location not found"**
   - Fix: Flutter create generates local.properties
   - Fix: Ensure `flutter create .` runs before build

3. **"AndroidManifest.xml not found"**
   - Fix: Our custom files are in repo, flutter create overlays
   - Fix: Verify files exist in workflow step

4. **"Plugin not found"**
   - Fix: Run `flutter pub get` before build
   - Fix: Check pubspec.yaml dependencies

5. **AGP compileSdk warning**
   - Fix: Add `android.suppressUnsupportedCompileSdk=34` to gradle.properties
   - Fix: Save/restore custom files after `flutter create --overwrite`

## Manual Workflow Trigger
If auto-trigger doesn't work:
1. Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
2. Click "Build Android APK" workflow
3. Click "Run workflow" → select `main` branch → "Run workflow"

## APK Output Locations
- Debug: `android/app/build/outputs/apk/debug/app-debug.apk`
- Release: `android/app/build/outputs/apk/release/app-release.apk`

## Artifact Retention
- Artifacts retained for 30 days
- Download from Actions → Artifacts section
