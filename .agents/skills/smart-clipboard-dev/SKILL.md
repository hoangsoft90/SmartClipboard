# Smart Clipboard — Development Skill

## Project Overview
Smart Clipboard & Text Expander — Personal Text Memory app built with Flutter.

## Tech Stack
- **Framework**: Flutter 3.24.0
- **State Management**: Riverpod
- **Database**: SQLite (sqflite) with WAL mode
- **Platform**: Android (primary), Web (limited)

## Repository
- **URL**: `https://github.com/hoangsoft90/SmartClipboard`
- **Branch**: `main`

## Development Workflow

### 1. Code Changes
- Edit files in `lib/` directory
- Follow existing code patterns (Riverpod providers, repository pattern)
- Add tests in `test/` directory

### 2. Push Changes
```bash
git add -A
git commit -m "descriptive message"
git push origin main
```

### 3. Build Debug APK (ALWAYS on GH Actions)
**NEVER build locally!** User explicitly said: "Tuyệt đối ko build apk trên local"

Workflow auto-triggers on push to main. Check status:
```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"
```

### 4. Download APK
- Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
- Click workflow run → Download `smart-clipboard-debug-apk`

## Project Structure
```
lib/
├── core/           # Constants, database, utils
├── models/         # Data models
├── repositories/   # Database operations
├── screens/        # UI screens
├── services/       # Business logic
├── state/          # Riverpod providers
└── widgets/        # Reusable widgets
```

## Key Features (Phase 0)
- Clipboard History with foreground capture
- Snippets & Folders management
- Expander Playground (type `;trigger` + space)
- Sensitive data heuristic (regex + entropy)
- Biometric app lock
- Encrypted backup/restore (AES-256-GCM)
- Local-only metrics

## Build Configuration
- **Android SDK**: API 34 (compileSdk), API 23 (minSdk)
- **Java**: 17
- **Gradle**: 8.3
- **Network**: HTTP cleartext allowed (network_security_config.xml)

## Testing
```bash
# Run tests (will be run on GH Actions)
flutter test

# Run analyzer
flutter analyze
```

## Common Issues

### 1. Build fails on GH Actions
- Check workflow logs: `https://github.com/hoangsoft90/SmartClipboard/actions`
- Common: Flutter create overlay issues
- Fix: Ensure custom Android files exist in repo

### 2. Missing dependencies
- Run: `flutter pub get`
- Check: `pubspec.yaml` for correct versions

### 3. Android manifest issues
- Our custom `AndroidManifest.xml` is in repo
- `flutter create` overlays with our version
- Verify: `network_security_config.xml` exists

### 4. AGP compileSdk warning
- Fix: Add `android.suppressUnsupportedCompileSdk=34` to gradle.properties
- Fix: Save/restore custom files after `flutter create --overwrite`

## Important Rules
1. **NEVER build locally** — always use GH Actions
2. **Use environment variable** for GH token (not hardcoded)
3. **Push to main branch** triggers auto-build
4. **Check build status** before downloading APK
5. **30-day artifact retention** — download promptly

## Quick Reference

### Push and Build
```bash
git add -A && git commit -m "message" && git push origin main
```

### Check Build Status
```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"
```

### Download APK (manual)
1. Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
2. Click latest workflow run
3. Click "Artifacts" section
4. Download `smart-clipboard-debug-apk`
