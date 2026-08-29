# Flutter Android CI — GitHub Actions Build

## Trigger
- User says "build APK", "build android", "CI setup", "GitHub Actions Flutter"
- Any Flutter project that needs Android APK build on CI

## Overview
Setup và troubleshoot GitHub Actions workflow cho Flutter Android project. Cover tất cả common pitfalls đã gặp thực tế.

## Workflow Template

```yaml
name: Build Android APK
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

env:
  FLUTTER_VERSION: "3.24.0"  # Pin cụ thể, KHÔNG dùng "stable"
  JAVA_VERSION: "17"

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: "temurin", java-version: "17" }
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: "stable"
          cache: true

      # === CRITICAL: Save custom files before flutter create ===
      - name: Save custom files
        run: |
          mkdir -p /tmp/backup
          cp pubspec.yaml /tmp/backup/
          cp pubspec.lock /tmp/backup/ 2>/dev/null || true
          cp -r lib /tmp/backup/lib     # QUAN TRỌNG nhất
          cp android/app/build.gradle /tmp/backup/
          cp android/build.gradle /tmp/backup/
          cp android/settings.gradle /tmp/backup/
          cp android/gradle.properties /tmp/backup/
          cp -r android/app/src/main/res /tmp/backup/res
          cp -r android/app/src/main/kotlin /tmp/backup/kotlin 2>/dev/null || true

      # === flutter create generates android scaffolding ===
      - name: Generate platform scaffolding
        run: flutter create . --platforms android --overwrite

      # === CRITICAL: Restore custom files ===
      - name: Restore custom files
        run: |
          cp /tmp/backup/pubspec.yaml .
          cp /tmp/backup/pubspec.lock . 2>/dev/null || true
          rm -rf lib && cp -r /tmp/backup/lib .  # PHẢI rm -rf trước
          cp /tmp/backup/build.gradle android/app/build.gradle
          cp /tmp/backup/root-build.gradle android/build.gradle
          cp /tmp/backup/settings.gradle android/settings.gradle
          cp /tmp/backup/gradle.properties android/gradle.properties
          cp -r /tmp/backup/res/* android/app/src/main/res/
          cp -r /tmp/backup/kotlin/* android/app/src/main/kotlin/ 2>/dev/null || true

      # === Force correct Gradle version ===
      - name: Fix Gradle version
        run: |
          sed -i 's|gradle-[0-9.]*-all.zip|gradle-8.3-all.zip|g' \
            android/gradle/wrapper/gradle-wrapper.properties

      - run: flutter pub get
      - run: flutter analyze --no-pub || true
      - run: flutter test --no-pub || true

      - name: Build APK
        run: |
          cd android && chmod +x gradlew
          ./gradlew assembleDebug assembleRelease --stacktrace

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

#### 2. Gradle version mismatch
**Symptom**: `Minimum supported Gradle version is 8.0. Current version is 7.6.3`
**Root cause**: Flutter generates old Gradle wrapper
**Fix**: `sed -i` force version sau restore

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

#### 14. Kotlin lambda type mismatch for Java interface
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
- [ ] Gradle wrapper ≥ 8.0?

### Workflow
- [ ] lib/ được save + restore?
- [ ] Upload paths bao gồm `build/app/outputs/`?
- [ ] Token dùng env var, KHÔNG hardcode?
