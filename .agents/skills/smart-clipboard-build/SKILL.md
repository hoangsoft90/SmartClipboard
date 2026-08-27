# Smart Clipboard — Build Debug APK on GitHub Actions

## Trigger
- User says "build debug APK", "build apk", "đóng gói", "tạo APK"

## CÁCH THỰC HIỆN (dùng GitHub Actions, TUYỆT ĐỐI KHÔNG build local)

### Prerequisites
- Repo: `https://github.com/hoangsoft90/SmartClipboard`
- Token: dùng `GH_TOKEN` env var (KHÔNG hardcode trong code — GitHub secret scanning sẽ block)

### Workflow: `.github/workflows/build-android.yml`

Luồng build tự động chạy khi push to `main`. Workflow thực hiện:
1. Checkout repo
2. Setup Java 17 + Flutter 3.24.0
3. **Save** custom files (pubspec, lib/, android/) trước flutter create --overwrite
4. `flutter create --overwrite` (tạo android scaffolding)
5. **Restore** custom files + force Gradle 8.3 via `sed`
6. flutter pub get → analyze → test → build APK

### Artifact download
- Vào https://github.com/hoangsoft90/SmartClipboard/actions
- Click build gần nhất → Artifacts section → tải debug/release APK
- APK paths: `build/app/outputs/apk/debug/app-debug.apk` (NOT `android/app/build/`)

---

## BÀI HỌC CI/BUILD (từ 14+ lần build thất bại)

### 1. `flutter create --overwrite` phá hủy TOÀN BỘ project files
**Vấn đề**: Lệnh này overwrite pubspec.yaml, lib/main.dart (thay bằng Flutter demo counter), android/ (mất custom config), gradle-wrapper.properties (tạo version cũ)

**Fix**: Save + Restore TẤT CẢ:
```yaml
# Save
cp pubspec.yaml /tmp/custom-backup/pubspec.yaml
cp -r lib /tmp/custom-backup/lib          # QUAN TRỌNG: lib/ chứa app code
cp -r android/app/src/main/res /tmp/custom-backup/res
cp android/app/build.gradle /tmp/custom-backup/app-build.gradle
# ... còn lại

# Restore
cp /tmp/custom-backup/pubspec.yaml pubspec.yaml
rm -rf lib && cp -r /tmp/custom-backup/lib lib    # PHẢI rm -rf trước
cp -r /tmp/custom-backup/res/* android/app/src/main/res/
cp /tmp/custom-backup/app-build.gradle android/app/build.gradle
# ...
```

**Lesson**: KHÔNG BAO GIỜ dùng `flutter create --overwrite` mà không save/restore lib/ — sẽ hiện Flutter demo thay vì app thật.

### 2. Gradle wrapper version mismatch
**Vấn đề**: Flutter 3.24 tạo Gradle 7.6.3, nhưng AGP cần ≥8.0 → `Minimum supported Gradle version is 8.0`

**Fix**: `sed -i` force version SAU restore:
```bash
sed -i 's|gradle-[0-9.]*-all.zip|gradle-8.3-all.zip|g' \
  android/gradle/wrapper/gradle-wrapper.properties
```

### 3. shrinkResources + minifyEnabled conflict
**Vấn đề**: Flutter Gradle Plugin tự set `shrinkResources=true`, build.gradle có `minifyEnabled=false` → crash

**Fix**: KHÔNG set cả hai, để Flutter Gradle Plugin tự quản:
```groovy
buildTypes {
    release {
        signingConfig signingConfigs.debug
        // KHÔNG minifyEnabled, KHÔNG shrinkResources
    }
}
```

### 4. Missing icon resources
**Vấn đề**: `android:banner="@drawable/ic_launcher"` (TV-only) + thiếu PNG fallback cho pre-API-26

**Fix**:
- Xóa `android:banner` khỏi AndroidManifest.xml
- Tạo PNG icons cho mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}
- Adaptive icons (mipmap-anydpi-v26) chỉ cover API 26+

### 5. JVM target inconsistency (Java vs Kotlin)
**Vấn đề**: `receive_sharing_intent` plugin force Kotlin `jvmTarget="17"`, Java set `VERSION_1_8` → crash

**Fix**:
1. Set Java + Kotlin cả hai về 17 trong app/build.gradle
2. Force ALL subprojects trong root build.gradle:
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

### 6. afterEvaluate fails when project already evaluated
**Vấn đề**: `evaluationDependsOn(":app")` force app evaluate trước → `afterEvaluate` crash

**Fix**: Dùng `gradle.projectsEvaluated` thay vì `afterEvaluate`

### 7. APK output path sai
**Vấn đề**: `rootProject.buildDir = "../build"` trong build.gradle redirect output → APK nằm ở `./build/` thay vì `android/app/build/`

**Fix**: Upload cả 2 paths:
```yaml
path: |
  build/app/outputs/apk/debug/*.apk
  build/app/outputs/flutter-apk/app-debug.apk
  android/app/build/outputs/apk/debug/*.apk
```

---

## BÀI HỌC CODE/DART (từ debug trên thiết bị thật)

### 8. PRAGMA SQLite phải dùng rawQuery() trên Android
**Vấn đề**: `db.execute('PRAGMA journal_mode=WAL')` → crash `DatabaseException: Queries can be performed using SQLiteDatabase query or rawQuery methods only`

**Fix**:
```dart
// SAI — crash trên Android
await db.execute('PRAGMA journal_mode=WAL');

// ĐÚNG
await db.rawQuery('PRAGMA journal_mode=WAL');
```

**Lesson**: sqflite Android KHÔNG cho phép PRAGMA qua `execute()`. PHẢI dùng `rawQuery()`.

### 9. AppSettings const constructor với List.last
**Vấn đề**: `const AppSettings({this.expirationDays = AppLimits.expirationOptionsDays.last})` → `Not a constant expression`

**Fix**: Dùng factory constructor:
```dart
const AppSettings._({required this.expirationDays, ...});
factory AppSettings({int? expirationDays, ...}) =>
    AppSettings._(expirationDays: expirationDays ?? 30, ...);
```

### 10. Snippet thiếu copyWith()
**Vấn đề**: Gọi `snippet.copyWith(...)` nhưng class không có method → compile error

**Fix**: Luôn thêm `copyWith()` cho mọi data model:
```dart
Snippet copyWith({String? id, String? title, ...}) =>
    Snippet(id: id ?? this.id, title: title ?? this.title, ...);
```

### 11. AsyncValue<int> không phải int
**Vấn đề**: `final total = count + snippetArchived` nhưng `snippetArchived` là `AsyncValue<int>` → type error

**Fix**: Extract `.value` trước khi cộng:
```dart
final snippetCount = snippetArchived.value ?? 0;
final total = count + snippetCount;
```

### 12. encrypt package: IV.fromBytes không tồn tại
**Vấn đề**: `IV.fromBytes(nonce)` → `Member not found`

**Fix**: Dùng constructor `IV(Uint8List)`:
```dart
// SAI
enc.IV.fromBytes(nonce)
// ĐÚNG
enc.IV(nonce)
```

### 13. Thiếu import Database từ sqflite
**Vấn đề**: Repository files dùng `Database` type nhưng không import → `'Database' isn't a type`

**Fix**: Thêm import ở mọi file dùng `Database`:
```dart
import 'package:sqflite/sqflite.dart';
```

---

## CHECKLIST TRƯỚC KHI PUSH (tránh mất 14 vòng build)

### Code checks
- [ ] Mọi model có `copyWith()`?
- [ ] Mọi file dùng `Database` đã import `sqflite`?
- [ ] PRAGMA dùng `rawQuery()` không phải `execute()`?
- [ ] `AsyncValue<T>.value` extract trước khi dùng như `T`?
- [ ] Không có `const` constructor gọi List.last hoặc expression không constant?
- [ ] `encrypt` package dùng `IV(Uint8List)` không phải `IV.fromBytes`?

### Android checks
- [ ] build.gradle KHÔNG có `minifyEnabled` hay `shrinkResources`?
- [ ] Java + Kotlin cả hai cùng JVM target (17)?
- [ ] AndroidManifest.xml KHÔNG có `android:banner`?
- [ ] Mipmap PNG icons tồn tại cho tất cả density?
- [ ] `gradle-wrapper.properties` dùng Gradle 8.3+?

### Workflow checks
- [ ] lib/ được save + restore trong workflow?
- [ ] Upload paths bao gồm cả `build/app/outputs/`?
- [ ] `sed` force Gradle version SAU restore?
- [ ] Token KHÔNG hardcode trong code?
