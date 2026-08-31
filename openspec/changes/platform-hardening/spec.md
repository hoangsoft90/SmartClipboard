# Platform Hardening

## Overview

4 thay đổi nền tảng: đổi package name, cho phép HTTP cleartext, nâng targetSdkVersion 36, tích hợp Sentry SDK.

---

## 1. Package Rename

**Từ**: `com.smartclip.smartclipboard`
**Đến**: `com.hoangsoft90.smartclipboard`

### Files ảnh hưởng
- `android/app/build.gradle` — `applicationId`, `namespace`
- `android/app/src/main/kotlin/com/smartclip/smartclipboard/` — rename thư mục
- `AndroidManifest.xml` — `FileProvider` authority `${applicationId}.fileprovider`
- `pubspec.yaml` — không đổi (Flutter name riêng, không phải Android package)

### Scenario: Rename thành công
- **GIVEN** package cũ `com.smartclip.smartclipboard`
- **WHEN** rename xong
- **THEN** `build.gradle` dùng `com.hoangsoft90.smartclipboard`; tất cả Kotlin files nằm đúng package; FileProvider authority đúng; build GH Actions pass

---

## 2. HTTP Cleartext Traffic

**Vấn đề**: Release APK block HTTP plaintext. Sentry SDK cần gửi event qua HTTPS nhưng trong tương lai có thể cần HTTP cho debug/internal APIs.

### Files ảnh hưởng
- `android/app/src/main/AndroidManifest.xml` — thêm `android:usesCleartextTraffic="true"` vào `<application>`
- Tạo `android/app/src/main/res/xml/network_security_config.xml` — cho phép tất cả domain HTTP

### Scenario: HTTP domain hoạt động
- **GIVEN** release APK built
- **WHEN** app gọi HTTP endpoint (không phải HTTPS)
- **THEN** request thành công, không bị block bởi Network Security

---

## 3. Target SDK 36

**Yêu cầu**: Google Play yêu cầu API 36 từ 31/8/2026.

### Files ảnh hưởng
- `android/app/build.gradle` — `targetSdk 36`, `compileSdk 36`

### Scenario: Build pass với targetSdk 36
- **GIVEN** compileSdk + targetSdk = 36
- **WHEN** build trên GH Actions
- **THEN** build thành công, không có deprecated API warning

---

## 4. Sentry SDK Integration

**DSN**: `https://7a668ce084082307784ece27aaa7a588@o4505474077753344.ingest.us.sentry.io/4512003088908288`

### Files ảnh hưởng
- `pubspec.yaml` — thêm `sentry_flutter: ^8.0.0`
- `lib/main.dart` — init `SentryFlutter.init()` wrapping `runApp()`
- `android/app/build.gradle` — không cần thêm gì (sentry-android auto-init via Flutter plugin)

### Requirements

#### Requirement: Sentry capture Flutter errors
Sentry init với DSN, wrap `runApp()` trong `SentryFlutter.init()`. Bắt cả Dart errors (`FlutterError.onError`) và platform errors (`PlatformDispatcher.instance.onError`).

#### Scenario: Flutter error được gửi lên Sentry
- **GIVEN** Sentry initialized với DSN
- **WHEN** có uncaught Flutter error (ví dụ `setState` sau `dispose`)
- **THEN** error xuất hiện trên Sentry dashboard với stack trace, device info, OS version

#### Scenario: Normal operation không gửi noise
- **GIVEN** Sentry initialized
- **WHEN** app chạy bình thường, không có error
- **THEN** không có event nào gửi lên Sentry

---

## Dependency Changes

```yaml
# pubspec.yaml — thêm
dependencies:
  sentry_flutter: ^8.0.0
```

Không thay đổi whitelist hiện tại vì `sentry_flutter` là dependency mới cần thêm.

---

## Build Impact
- Package rename cần clean build
- targetSdk 36 cần Gradle/AGP tương thích (AGP 8.1.0 hỗ trợ SDK 36)
- Sentry SDK thêm ~2MB vào APK size

---

## Cần làm rõ
- Package rename có cần đổi app name hiển thị không? (hiện tại là "Smart Clipboard" — giữ nguyên)
- Sentry có nên enable trong debug mode không? (mặc định: chỉ enable trong release)
