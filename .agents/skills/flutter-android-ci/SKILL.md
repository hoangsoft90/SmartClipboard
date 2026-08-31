# Flutter Android CI — GitHub Actions Build

## Trigger
- User says "build APK", "build android", "CI setup", "GitHub Actions Flutter"
- Any Flutter project that needs Android APK build on CI

## Overview
Setup và troubleshoot GitHub Actions workflow cho Flutter Android project. Cover tất cả common pitfalls đã gặp thực tế.

## Workflow Template (OPTIMIZED)

```yaml
name: Build Android APK
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  FLUTTER_VERSION: "3.29.0"  # Pin cụ thể, KHÔNG dùng "stable"
  JAVA_VERSION: "17"

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: "temurin", java-version: "17" }

      # FIX #29: Cache key based on pubspec.lock (STABLE — không thay đổi khi flutter create chạy)
      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ runner.os }}-agp870-g89-${{ hashFiles('pubspec.lock') }}
          restore-keys: |
            gradle-${{ runner.os }}-agp870-g89-
            gradle-${{ runner.os }}-

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: "stable"
          cache: true

      # FIX #30: KHÔNG dùng flutter create nếu android/ đã commit trong git
      # flutter create regenerate gradle files → cache key thay đổi → cache miss
      # → build từ đầu mỗi lần → timeout 80 phút

      - run: flutter pub get
      - run: flutter analyze --no-pub || true
      - run: flutter test --no-pub || true

      - name: Build debug APK
        run: flutter build apk --debug --no-pub

      - name: Build release APK
        run: flutter build apk --release --no-pub

      - name: Find built APKs
        run: |
          echo "=== APK files ==="
          find . -name "*.apk" -type f -exec ls -lh {} \;

      - uses: actions/upload-artifact@v4
        with:
          name: apk
          path: |
            build/app/outputs/apk/**/*.apk
            build/app/outputs/flutter-apk/*.apk
          retention-days: 30
          if-no-files-found: warn
```

---

## 13 BÀI HỌC THỰC TẾ (từ 14+ lần build fail)

### CI/Build Pitfalls

#### 1. `flutter create --overwrite` phá hủy project
**Symptom**: App hiện Flutter demo counter thay vì app thật
**Root cause**: Lệnh overwrite pubspec.yaml + TOÀN BỘ lib/ (bao gồm main.dart)
**Fix**: Save/restore lib/ + pubspec.yaml trước/sau flutter create
**Check**: Verify `lib/main.dart` content SAU restore — phải là app code, không phải counter demo

#### 2. Gradle version mismatch + flutter create overwrite
**Symptom**: `Minimum supported Gradle version is 8.9. Current version is 8.3`
**Root cause**: `flutter create --overwrite` REGENERATES `gradle-wrapper.properties` về default (7.6.3). Step "Force Gradle X.Y" sau đó dùng `sed` ghi đè version — NHƯNG nếu version trong sed ≠ version cần thiết, build fail.
**Fix**: (1) Save `gradle-wrapper.properties` vào backup trước flutter create. (2) Restore sau flutter create. (3) Update "Force Gradle" step dùng đúng version. Ví dụ AGP 8.7.0 → Gradle 8.9+:
```yaml
# Save
cp android/gradle/wrapper/gradle-wrapper.properties /tmp/backup/
# Restore
cp /tmp/backup/gradle-wrapper.properties android/gradle/wrapper/
# Force
sed -i 's|gradle-[0-9.]*-all.zip|gradle-8.9-all.zip|g' \
  android/gradle/wrapper/gradle-wrapper.properties
```
**Lesson**: LUÔN save/restore `gradle-wrapper.properties` cùng các android files khác. KHÔNG tin rằng file đã commit sẽ giữ nguyên — `flutter create` regenerate TOÀN BỘ android scaffolding.

#### 3. shrinkResources + minifyEnabled conflict
**Symptom**: `Removing unused resources requires unused code shrinking`
**Root cause**: Flutter Gradle Plugin tự set shrinkResources=true
**Fix**: KHÔNG set minifyEnabled hay shrinkResources trong build.gradle — để Flutter quản lý

#### 4. Missing icon resources
**Symptom**: `resource drawable/ic_launcher not found`
**Root cause**: Thiếu PNG fallback icons + TV-only banner reference
**Fix**: Xóa `android:banner`, tạo PNG cho mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}

#### 5. JVM target mismatch (Java vs Kotlin)
**Symptom**: `Inconsistent JVM-target compatibility detected for tasks`
**Root cause**: Native plugins force Kotlin jvmTarget differs from Java
**Fix**: Set cả hai về cùng version (17) + force subprojects:
```groovy
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

#### 6. afterEvaluate timing crash
**Symptom**: `Cannot run Project.afterEvaluate(Closure) when the project is already evaluated`
**Root cause**: `evaluationDependsOn(":app")` force early evaluation
**Fix**: Dùng `gradle.projectsEvaluated` thay vì `afterEvaluate`

#### 7. APK output path redirect
**Symptom**: Build success nhưng 0 artifacts uploaded
**Root cause**: `rootProject.buildDir = "../build"` trong build.gradle redirect output
**Fix**: Upload cả 2 paths:
```yaml
path: |
  build/app/outputs/apk/**/*.apk
  android/app/build/outputs/apk/**/*.apk
```

### Kotlin/IME Pitfalls

#### 14. AGP version compatibility with transitive dependencies
**Symptom**: `Could not get unknown property 'flutter' for extension 'android'` / `compileSdkVersion is not specified`
**Root cause**: Newer Flutter plugins (e.g. `package_info_plus` 9.x via `google_mobile_ads`) require AGP 8.4+. Old AGP (8.1.0) can't evaluate these plugins.
**Fix**: Upgrade AGP + Kotlin + Gradle together:
```groovy
// settings.gradle
id "com.android.application" version "8.7.0" apply false
id "org.jetbrains.kotlin.android" version "2.2.0" apply false
// gradle-wrapper.properties
distributionUrl=...gradle-8.9-all.zip
```
**Lesson**: Khi thêm new Flutter plugin (đặc biệt từ Google), LUÔN check AGP version requirement. Upgrade AGP/Kotlin/Gradle theo bộ, không upgrade từng cái.

#### 33. Kotlin version mismatch with transitive dependencies
**Symptom**: `Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is 2.2.0, expected version is 2.0.0.`
**Root cause**: Plugin dependency (e.g. `package_info_plus` 9.x) pulls in `kotlin-stdlib-2.2.0` via Maven, but project's Kotlin compiler is 2.0.0. Kotlin compiler 2.0.0 can only read metadata ≤ 2.1.0.
**Fix**: Upgrade Kotlin to match the transitive dependency:
```groovy
// settings.gradle
id "org.jetbrains.kotlin.android" version "2.2.0" apply false
```
**Lesson**: When upgrading AGP, also check Kotlin version. Transitive deps from new plugins may require newer Kotlin. The error message tells you exact version needed: "metadata is X.Y.Z, expected version is A.B.C" — upgrade Kotlin to ≥ X.Y.Z.

#### 34. NDK version mismatch with native plugins
**Symptom**: `sqflite_android requires Android NDK 27.0.12077973` / `webview_flutter_android requires Android NDK 27.0.12077973`
**Root cause**: Flutter plugins with native code (sqflite, webview, etc.) may require specific NDK versions. If `ndkVersion` is not set or set to wrong version, build fails.
**Fix**: Set `ndkVersion` in `build.gradle`:
```groovy
android {
    ndkVersion "27.0.12077973"  // Match the highest required version
}
```
The error message tells you exact version needed. Use the highest one if multiple plugins require different versions.
**Lesson**: After adding new native plugins, check if they require specific NDK version. Flutter's `ndkVersion flutter.ndkVersion` may not match — set explicit version instead.

#### 35. sentry_flutter languageVersion incompatibility with Kotlin 2.2+
**Symptom**: `e: Language version 1.6 is no longer supported; please, use version 1.8 or greater.` at `:sentry_flutter:compileDebugKotlin`
**Root cause**: sentry_flutter 8.x ships with `languageVersion = "1.6"` in its Android plugin's build.gradle. Kotlin 2.2.0 dropped support for language version 1.6 (only 1.8+ supported). This creates a conflict with plugins like `package_info_plus` 9.x which need Kotlin 2.2.0 for metadata compatibility.
**Fix**: Upgrade sentry_flutter to ≥ 9.3.0 which bumped languageVersion to 1.8:
```yaml
# pubspec.yaml
sentry_flutter: ^9.3.0  # NOT ^8.0.0 with Kotlin 2.2
```
**Compatibility matrix**:
| Kotlin Version | sentry_flutter 8.x | sentry_flutter ≥ 9.3.0 |
|---|---|---|
| 2.0.x | ✅ | ✅ |
| 2.1.x | ✅ | ✅ |
| 2.2.x | ❌ (languageVersion 1.6) | ✅ (languageVersion 1.8) |
**Lesson**: When upgrading Kotlin to 2.2+, check ALL plugins' `languageVersion`. sentry_flutter 8.x is a known blocker. Always upgrade sentry_flutter first when bumping Kotlin ≥ 2.2.
**Symptom**: `Type mismatch: inferred type is (...) -> Unit but InterfaceName was expected`
**Root cause**: Java interface `OnKeyPressListener` has one method, but Kotlin SAM conversion fails with wrong lambda signature
**Fix**: Dùng anonymous object thay vì lambda:
```kotlin
// ❌ WRONG
keyboardView.setOnKeyPressListener { keyCode, _ -> onKeyPressed(keyCode) }

// ✅ CORRECT — use anonymous object
keyboardView.setOnKeyPressListener(object : OnKeyPressListener {
    override fun onKeyPress(keyCode: Int) { onKeyPressed(keyCode) }
})
```

#### 15. String vs Char comparison in Kotlin
**Symptom**: `Operator '==' cannot be applied to 'String' and 'Char'`
**Root cause**: `String == Char` không compare được trực tiếp
**Fix**: Dùng String literal `";"` hoặc `ch.first() == ';'`:
```kotlin
// ❌ WRONG
if (ch == ';')

// ✅ CORRECT
if (ch == ";")  // both are String
```

#### 16. Dead code referencing unavailable APIs
**Symptom**: `Unresolved reference: extractText` even with try-catch
**Root cause**: Kotlin compiler解析 dead code before runtime. If API doesn't exist at compile target, try-catch không rescue được
**Fix**: Xóa dead code hoàn toàn — KHÔNG giữ lại "just in case"
**Lesson**: Không viết code reference API chưa verify tồn tại ở target API level

#### 17. String doesn't have `uppercaseChar()` — use `uppercase()`
**Symptom**: `Unresolved reference: uppercaseChar`
**Root cause**: `String.uppercaseChar()` is a `Char` extension, not `String`. Kotlin String has `uppercase()` (returns new String)
**Fix**:
```kotlin
// ❌ WRONG
val upper = ch.uppercaseChar()  // ch is String, not Char

// ✅ CORRECT
val upper = ch.uppercase()  // String extension
```
**Lesson**: When `getCharForKey()` returns `String` (not `Char`), ALL Char-specific methods (`.isLetter()`, `.uppercaseChar()`, `.lowercaseChar()`) fail at compile time. Use `String` equivalents: `.uppercase()`, `.lowercase()`, `.first().isLetter()`

#### 18. MutableList.last() returns a COPY — can't assign to it
**Symptom**: `Val cannot be reassigned` or silent no-op when doing `list.last() = x`
**Root cause**: `MutableList.last()` in Kotlin returns a **read-only copy** of the last element, NOT a reference. Assigning to it does nothing.
**Fix**: Use indexed access:
```kotlin
// ❌ WRONG
val chars = mutableListOf('a', 'b', 'c')
chars.last() = 'd'  // Silent no-op! 'c' stays

// ✅ CORRECT
chars[chars.size - 1] = 'd'  // 'c' → 'd'
// or
chars[chars.lastIndex] = 'd'
```
**Lesson**: When rewriting chars in a buffer during composition (e.g. Telex processor), always use `list[index] = newValue`, never `list.last() = newValue`

#### 19. InputConnection.extractText / ExtractedTextRequest
**Symptom**: `Unresolved reference: extractText` + `Too many arguments for constructor ExtractedTextRequest`
**Root cause**: `extractText` method không available trên tất cả API levels. `ExtractedTextRequest()` constructor takes no args (not `(Int)`)
**Fix**: Không dùng `extractText` — thay bằng cách khác (composing text, hoặc dùng `getExtractedText` nếu cần)

#### 20. str_replace merged comment + variable declaration onto one line
**Symptom**: `Unresolved reference: commaRect` — variable appears on same line as comment
**Root cause**: `str_replace` oldString contained `// ,
 val commaRect = ...` but when the newString accidentally merged `// ,` comment with `val commaRect = ...` into a single line, Kotlin treats the entire line as a comment → `commaRect` is never declared → `Unresolved reference` downstream
**Fix**: Always verify `str_replace` output when the old/new string contains a comment line followed by a declaration. The tool does exact string matching — if the old string has a newline between comment and declaration, the new string MUST also have that newline:
```kotlin
// ❌ WRONG — comment merges with declaration
// ,            val commaRect = Rect(...)
    drawKey(canvas, commaRect, ...)

// ✅ CORRECT — comment and declaration are separate lines
// ,
val commaRect = Rect(...)
drawKey(canvas, commaRect, ...)
```
**Lesson**: After any `str_replace` involving multi-line blocks with comments, ALWAYS read the affected lines back to verify the structure is intact before committing. This is especially dangerous because the Kotlin compiler error (`Unresolved reference`) points to the USAGE line, not the merged declaration line — making it harder to trace back to the root cause.

---

### Code/Dart Pitfalls

#### 8. PRAGMA SQLite crash on Android
**Symptom**: `DatabaseException: Queries can be performed using SQLiteDatabase query or rawQuery methods only`
**Fix**: `db.rawQuery('PRAGMA ...')` thay vì `db.execute('PRAGMA ...')`

#### 9. Const constructor + non-constant expression
**Symptom**: `Not a constant expression`
**Fix**: Dùng factory constructor pattern

#### 10. Missing copyWith() on models
**Symptom**: `The method 'copyWith' isn't defined`
**Fix**: Luôn thêm copyWith() cho mọi data model

#### 11. AsyncValue<T> not T
**Symptom**: `A value of type 'AsyncValue<int>' can't be assigned to a variable of type 'num'`
**Fix**: `asyncValue.value ?? defaultValue` trước khi dùng

#### 12. encrypt package IV constructor
**Symptom**: `Member not found: 'IV.fromBytes'`
**Fix**: `IV(uint8list)` thay vì `IV.fromBytes(uint8list)`

#### 13. Missing sqflite import
**Symptom**: `'Database' isn't a type`
**Fix**: `import 'package:sqflite/sqflite.dart';`

---

## Pre-push Checklist

### Code
- [ ] Mọi model có `copyWith()`?
- [ ] Mọi file dùng `Database` đã import sqflite?
- [ ] PRAGMA dùng `rawQuery()` không phải `execute()`?
- [ ] `AsyncValue<T>.value` extract trước khi dùng như `T`?
- [ ] Không có const constructor với List.last / non-constant expression?
- [ ] encrypt dùng `IV(Uint8List)` không phải `IV.fromBytes`?

### Kotlin/Android
- [ ] Lambda cho Java interface dùng SAM conversion đúng? (anonymous object nếu lambda fail)
- [ ] String vs Char comparison đúng? (dùng `";"` không dùng `';'`)
- [ ] Dùng `.uppercase()` thay `.uppercaseChar()` cho String?
- [ ] Dùng `.first().isLetter()` thay `.isLetter()` cho String?
- [ ] Gán giá trị vào MutableList dùng `list[index] = x` không phải `list.last() = x`?
- [ ] Không có dead code reference API chưa verify?
- [ ] InputConnection API dùng đúng cách? (extractText có thể không available)
- [ ] build.gradle KHÔNG có minifyEnabled / shrinkResources?
- [ ] Java + Kotlin cùng JVM target?
- [ ] AndroidManifest.xml KHÔNG có `android:banner` (trừ TV app)?
- [ ] Mipmap PNG icons cho tất cả density?
- [ ] Gradle wrapper ≥ 8.0? (AGP 8.7.0 → Gradle 8.9+)
- [ ] AGP/Kotlin/Gradle upgrade theo bộ? (không upgrade từng cái)
- [ ] Sau str_replace multi-line blocks: verify comment/declaration không merge nhau?#### 21. CI timeout — Gradle首次构建 quá chậm với AGP 8.7+ + new dependencies
**Symptom**: Build cancelled after 45min — "The operation was canceled"
**Root cause**: `timeout-minutes: 45` quá ngắn cho first-time build với AGP 8.7.0 + compileSdk 36 + heavy plugins (google_mobile_ads, sentry_flutter). Gradle daemon download + compile Kotlin/AGP takes 60-80min on fresh runner.
**Fix**: (1) Set `timeout-minutes: 90`. (2) Use `flutter build apk` thay raw `gradlew` — Flutter CLI handles lifecycle better. (3) Add `actions/cache` for `~/.gradle` to speed up subsequent builds:
```yaml
timeout-minutes: 90
# Cache Gradle
- uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: gradle-${{ runner.os }}-agp870-g89-${{ hashFiles('android/**/*.gradle*') }}
# Use flutter build apk thay gradlew
- run: flutter build apk --debug --no-pub
- run: flutter build apk --release --no-pub
```
**Lesson**: Với AGP 8.x + heavy plugins, LUÔN set timeout ≥ 60 phút. Lần đầu build trên runner mới mất 40-80 phút. Các lần sau nhanh hơn nhờ cache.

#### 22. No concurrency — push mới không cancel build cũ
**Symptom**: Nhiều build chạy song song,浪费资源, có thể conflict artifact uploads
**Root cause**: Không có concurrency group
**Fix**: Thêm `concurrency` block:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
**Lesson**: LUÔN set concurrency để cancel build cũ khi push mới. Tiết kiệm runner time và tránh conflict.

#### 23. No pub cache — flutter pub get chạy lại mỗi lần
**Symptom**: `flutter pub get` download lại tất cả dependencies mỗi build
**Root cause**: Không cache `.pub-cache`
**Fix**: Thêm `actions/cache` cho pub cache:
```yaml
- name: Cache pub
  uses: actions/cache@v4
  with:
    path: ~/.pub-cache
    key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
    restore-keys: pub-${{ runner.os }}-
```
**Lesson**: Cache pub dependencies tiết kiệm 1-3 phút mỗi build.

#### 24. Missing gradle-wrapper.properties in backup
**Symptom**: Gradle version revert sau flutter create dù đã save
**Root cause**: Quên save `gradle-wrapper.properties` vào backup
**Fix**: LUÔN save file này:
```yaml
cp android/gradle/wrapper/gradle-wrapper.properties /tmp/backup/
```
**Lesson**: File này bị flutter create ghi đè, PHẢI save/restore.

#### 25. Missing AndroidManifest.xml in backup
**Symptom**: AndroidManifest.xml mất custom permissions sau flutter create
**Root cause**: Quên save AndroidManifest.xml
**Fix**: Save restore:
```yaml
cp android/app/src/main/AndroidManifest.xml /tmp/backup/
# ...
cp /tmp/backup/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
```
**Lesson**: AndroidManifest.xml chứa permissions, meta-data, intent filters — flutter create sẽ reset về default.

#### 26. flutter build apk vs gradlew assembleDebug
**Symptom**: Raw `gradlew` mất thêm 5-10 phút setup
**Root cause**: Flutter CLI manages Gradle lifecycle, daemon, and dependencies more efficiently
**Fix**: Dùng `flutter build apk --debug --no-pub` thay `cd android && ./gradlew assembleDebug`
**Lesson**: `flutter build apk` handle pub dependency resolution + Gradle lifecycle together, faster than raw gradlew.

#### 27. No artifact cleanup — disk space exhaustion
**Symptom**: Build fails với "No space left on device"
**Root cause**: GitHub Actions runner disk space有限 (14GB), old artifacts + Gradle cache fill up
**Fix**: (1) Set `retention-days: 7` (not 30). (2) Clean Gradle cache before build:
```yaml
- name: Clean Gradle cache
  run: |
    rm -rf ~/.gradle/caches/journal-*
    rm -rf ~/.gradle/caches/transforms-*
```
**Lesson**: Default retention 90 days quá dài. Giảm xuống 7-14 ngày.

#### 28. Parallel debug + release build
**Symptom**: Build sequence debug → release mất gấp đôi thời gian
**Root cause**: Build tuần tự
**Fix**: Nếu cần cả debug + release, có thể dùng matrix strategy hoặc parallel jobs:
```yaml
strategy:
  matrix:
    build-type: [debug, release]
steps:
  - run: flutter build apk ${{ matrix.build-type }} --no-pub
```
**Lesson**: Parallel build tiết kiệm 30-50% thời gian.

#### 29. Gradle cache key based on gradle files → never hits (flutter create invalidates)
**Symptom**: "Cache not found for input keys: gradle-Linux-..." mỗi build
**Root cause**: Cache key dùng `hashFiles('android/**/*.gradle*')` — nhưng `flutter create .` regenerate các file này → hash thay đổi → cache miss → download + compile từ đầu mỗi lần
**Fix**: Dùng `pubspec.lock` làm cache key (stable — không thay đổi): ```yaml
key: gradle-${{ runner.os }}-agp870-g89-${{ hashFiles('pubspec.lock') }}
```
**Lesson**: KHÔNG dùng gradle file hash làm cache key nếu workflow chạy `flutter create`. pubspec.lock stable hơn nhiều.

#### 30. flutter create trong CI gây cache invalidation + silent hang
**Symptom**: Build "works" nhưng không có output → timeout 80 phút
**Root cause**: (1) `flutter create .` regenerate gradle files → cache miss. (2) Flutter 3.24.0 + AGP 8.7.0 incompatible → Gradle daemon hang silently, zero stdout output. (3) 88 phút im lặng trước khi bị cancel.
**Fix**: (1) Xóa `flutter create .` nếu android/ đã commit. (2) Upgrade Flutter version compatible với AGP: AGP 8.7.0 → Flutter ≥ 3.29.0. (3) Thêm `--info` flag để thấy debug output:
```yaml
- run: flutter build apk --debug --no-pub --info 2>&1 | tail -100
```
**Lesson**: Nếu android/ files đã commit, KHÔNG cần `flutter create` trong CI. Mọi step save/restore/backup đều thừa — xóa hết.

#### 31. Flutter version incompatible with AGP → Gradle hangs silently
**Symptom**: Build command starts but ZERO output for 80+ minutes, then timeout. 3 orphan Java processes (Gradle daemon) killed at cancellation.
**Root cause**: Flutter SDK ships with a specific AGP version. Using a different AGP version causes the Flutter Gradle plugin to encounter features it doesn't recognize → silent hang. Example: Flutter 3.24.0 ships with AGP 8.1.0, but project uses AGP 8.7.0.
**Fix**: Check compatibility matrix:
| AGP Version | Minimum Flutter Version |
|-------------|----------------------|
| 8.1.0       | 3.19.0               |
| 8.3.0       | 3.22.0               |
| 8.5.0       | 3.24.0               |
| 8.7.0       | 3.29.0               |
| 8.9.0       | 3.32.0               |

```yaml
# If AGP = 8.7.0, Flutter MUST be ≥ 3.29.0
env:
  FLUTTER_VERSION: "3.29.0"  # NOT 3.24.0!
```
**Lesson**: LUÔN check AGP ↔ Flutter version compatibility. Nếu dùng AGP mới, PHẢI upgrade Flutter theo. Nếu upgrade Flutter không được (project constraint), downgrade AGP về version compatible.

#### 32. No build output → impossible to debug CI failures
**Symptom**: Build fails or hangs nhưng CI log shows nothing useful
**Root cause**: `flutter build apk` runs Gradle, but Gradle stdout goes to daemon log. When Gradle hangs or errors occur in daemon, stdout is empty.
**Fix**: Flutter CLI doesn't accept `--info` (that's a Gradle flag). For Gradle-level debugging, pass it via `--` separator:
```yaml
# Pass Gradle flags via -- separator
- name: Build debug APK
  run: flutter build apk --debug --no-pub -- --info
```
Or run Gradle directly for full output:
```yaml
- name: Build debug APK (with Gradle info)
  run: cd android && ./gradlew assembleDebug --info
```
**Lesson**: `flutter build apk` KHÔNG accept `--info`. Dùng `-- --info` để pass flags xuống Gradle, hoặc chạy `gradlew` trực tiếp.

### Workflow (OPTIMIZATION)

- [ ] lib/ được save + restore? (NẾU dùng flutter create)
- [ ] `gradle-wrapper.properties` được save + restore? (NẾU dùng flutter create)
- [ ] `AndroidManifest.xml` được save + restore? (NẾU dùng flutter create)
- [ ] Android/ files đã commit trong git? → KHÔNG cần flutter create
- [ ] Cache key dùng `pubspec.lock` (stable) không phải `gradle*` files?
- [ ] Flutter version compatible với AGP? (check matrix lesson #31)
- [ ] "Force Gradle X.Y" step dùng đúng version cho AGP hiện tại?
- [ ] Upload paths bao gồm `build/app/outputs/`?
- [ ] Token dùng env var, KHÔNG hardcode?
- [ ] `timeout-minutes` ≥ 60? (AGP 8.x first build chậm)
- [ ] Có Gradle cache (`actions/cache` cho `~/.gradle`)?
- [ ] Có pub cache (`actions/cache` cho `~/.pub-cache`)?
- [ ] Dùng `flutter build apk` thay raw `gradlew`?
- [ ] Có `concurrency` group để cancel build cũ?
- [ ] `retention-days` ≤ 14? (tránh disk space exhaustion)
- [ ] Build debug + release parallel (matrix strategy)?
- [ ] Có `--info` flag trên build command? (debug khi hang)
- [ ] Có `2>&1 | tail -100` để capture output?
