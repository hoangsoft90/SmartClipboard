# Smart Clipboard — Project-Specific Build Config

## Trigger
- User says "build debug APK", "build apk", "đóng gói", "tạo APK" cho Smart Clipboard

## General CI/CD lessons → Xem skill `flutter-android-ci`
## General adb debug → Xem skill `flutter-android-debug`

---

## Project-Specific Config

### Repo
- **URL**: `https://github.com/hoangsoft90/SmartClipboard`
- **Branch**: `main`
- **Package**: `com.smartclip.smartclipboard`
- **Token**: dùng `GH_TOKEN` env var (KHÔNG hardcode)

### Workflow: `.github/workflows/build-android.yml`
- Flutter 3.24.0, Java 17, Gradle 8.3
- Auto-triggers on push to `main`
- Save/restore: pubspec.yaml, lib/, android/ (custom files)
- Force Gradle 8.3 via `sed`
- Upload: `build/app/outputs/apk/` (NOT `android/app/build/`)

### Build Configuration
```groovy
// android/app/build.gradle
android {
    namespace "com.smartclip.smartclipboard"
    compileSdk 34
    defaultConfig {
        applicationId "com.smartclip.smartclipboard"
        minSdk 23
        targetSdk 34
    }
    // KHÔNG có minifyEnabled / shrinkResources — Flutter tự quản
}

// android/build.gradle — force JVM target 17 cho tất cả subprojects
gradle.projectsEvaluated {
    rootProject.allprojects { proj ->
        proj.plugins.withId("com.android.application") {
            proj.android {
                compileOptions {
                    sourceCompatibility JavaVersion.VERSION_17
                    targetCompatibility JavaVersion.VERSION_17
                }
            }
        }
        proj.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile)
            .configureEach { kotlinOptions { jvmTarget = "17" } }
    }
}
```

### Key Files
- `android/app/src/main/AndroidManifest.xml` — custom (network security, share intent, biometric)
- `android/app/src/main/res/xml/network_security_config.xml` — HTTP cleartext all domains
- `android/app/src/main/kotlin/.../MainActivity.kt` — FlutterActivity stub (Phase 0)
- `android/app/src/main/res/mipmap-*/ic_launcher.png` — custom icons

### Debug on Phone
```bash
adb shell am force-stop com.smartclip.smartclipboard
adb logcat -c && adb shell am start -n com.smartclip.smartclipboard/.MainActivity
sleep 3 && adb logcat -d -t 300 | grep -i "flutter\|error\|exception"
```

### Check Build Status
```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/SmartClipboard/actions/runs?per_page=1"
```

### Download APK
1. Go to: `https://github.com/hoangsoft90/SmartClipboard/actions`
2. Click latest successful run → Artifacts → Download `smart-clipboard-debug-apk`
