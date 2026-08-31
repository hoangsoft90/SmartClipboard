# Platform Hardening

## Overview

3 thay đổi nền tảng: cho phép HTTP cleartext, nâng targetSdkVersion 36, tích hợp Sentry SDK. Package name giữ nguyên `com.smartclip.smartclipboard`.

---

## 1. HTTP Cleartext Traffic

**Vấn đề**: Release APK block HTTP plaintext. Cần cho phép HTTP cho tất cả domain (Sentry SDK, future internal APIs).

### Files ảnh hưởng
- `android/app/src/main/AndroidManifest.xml` — thêm `android:usesCleartextTraffic="true"` vào `<application>`
- Tạo `android/app/src/main/res/xml/network_security_config.xml` — cho phép tất cả domain HTTP

### Scenario: HTTP domain hoạt động
- **GIVEN** release APK built
- **WHEN** app gọi HTTP endpoint (không phải HTTPS)
- **THEN** request thành công, không bị block bởi Network Security

---

## 2. Target SDK 36

**Yêu cầu**: Google Play yêu cầu API 36 từ 31/8/2026.

### Files ảnh hưởng
- `android/app/build.gradle` — `targetSdk 36`, `compileSdk 36`

### Scenario: Build pass với targetSdk 36
- **GIVEN** compileSdk + targetSdk = 36
- **WHEN** build trên GH Actions
- **THEN** build thành công, không có deprecated API warning

---

## 3. Sentry SDK Integration

**DSN**: `https://7a668ce084082307784ece27aaa7a588@o4505474077753344.ingest.us.sentry.io/4512003088908288`

### Files ảnh hưởng
- `pubspec.yaml` — thêm `sentry_flutter: ^8.0.0`
- `lib/main.dart` — init `SentryFlutter.init()` wrapping `runApp()`

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

---

## Build Impact
- targetSdk 36 cần Gradle/AGP tương thích (AGP 8.1.0 hỗ trợ SDK 36)
- Sentry SDK thêm ~2MB vào APK size

---

## Cần làm rõ
- Sentry có nên enable trong debug mode không? (mặc định: chỉ enable trong release)
