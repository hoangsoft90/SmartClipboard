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
3. Save custom Android files (trước flutter create --overwrite)
4. `flutter create --overwrite` (tạo android scaffolding)
5. Restore custom files + force Gradle 8.3 via `sed`
6. flutter pub get → analyze → test → build APK

### Artifact download
- Vào https://github.com/hoangsoft90/SmartClipboard/actions
- Click build gần nhất → Artifacts section → tải debug/release APK

## BÀI HỌC TỪ 10 LẦN BUILD THẤT BẠI

### 1. `flutter create --overwrite` phá hủy project files
**Vấn đề**: Lệnh này overwrite TẤT CẢ包括pubspec.yaml (mất dependencies), android/ (mất custom config), gradle-wrapper.properties (tạo version cũ 7.6.3 thay vì 8.3)

**Fix**: Save custom files trước khi flutter create, restore sau đó:
```yaml
# Save
cp pubspec.yaml /tmp/custom-backup/pubspec.yaml
cp android/gradle/wrapper/gradle-wrapper.properties /tmp/custom-backup/gradle-wrapper.properties
# ... các file custom khác

# Restore
cp /tmp/custom-backup/pubspec.yaml pubspec.yaml
cp /tmp/custom-backup/gradle-wrapper.properties android/gradle/wrapper/gradle-wrapper.properties
# ...
```

### 2. Gradle wrapper version mismatch
**Vấn đề**: Flutter 3.24 tạo Gradle 7.6.3, nhưng AGP trong custom build.gradle cần ≥8.0 → `Minimum supported Gradle version is 8.0`

**Fix**: Dùng `sed -i` force version SAU restore:
```bash
sed -i 's|gradle-[0-9.]*-all.zip|gradle-8.3-all.zip|g' android/gradle/wrapper/gradle-wrapper.properties
```

### 3. shrinkResources + minifyEnabled conflict
**Vấn đề**: Flutter Gradle Plugin tự set `shrinkResources=true`, nhưng build.gradle có `minifyEnabled=false` → `Removing unused resources requires unused code shrinking`

**Fix**: Xóa cả hai, để Flutter Gradle Plugin tự quản:
```groovy
buildTypes {
    release {
        signingConfig signingConfigs.debug
        // KHÔNG set minifyEnabled hay shrinkResources — Flutter tự xử lý
    }
}
```

### 4. Missing icon resources
**Vấn đề**: `android:banner="@drawable/ic_launcher"` trong AndroidManifest → resource không tồn tại

**Fix**:
- Xóa `android:banner` (chỉ cho TV app)
- Tạo PNG fallback icons cho mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}
- Adaptive icons (mipmap-anydpi-v26) chỉ cover API 26+

### 5. JVM target inconsistency
**Vấn đề**: `receive_sharing_intent` plugin force Kotlin `jvmTarget="17"`, nhưng Java set `VERSION_1_8` → `Inconsistent JVM-target compatibility`

**Fix**: 
1. Set Java + Kotlin cả hai về 17 trong app/build.gradle
2. Dùng `gradle.projectsEvaluated` trong root build.gradle force ALL subprojects:
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
        proj.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
            kotlinOptions { jvmTarget = "17" }
        }
    }
}
```

### 6. afterEvaluate fails when project already evaluated
**Vấn đề**: `evaluationDependsOn(":app")` force app evaluate trước → `afterEvaluate` chạy sau khi project đã evaluated → crash

**Fix**: Dùng `gradle.projectsEvaluated` thay vì `afterEvaluate` trong subprojects

## Checklist khi fix build errors

1. ✅ Lấy log: `curl -s -L .../logs` → unzip → grep error
2. ✅ Xác định step nào fail (Build debug APK? Install dependencies?)
3. ✅ Đọc error message cẩn thận — thường là version mismatch hoặc missing resource
4. ✅ Fix trong repo → push → chờ workflow auto-trigger
5. ✅ KHÔNG build local — luôn dùng GH Actions
