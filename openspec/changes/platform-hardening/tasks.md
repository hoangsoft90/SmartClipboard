# Platform Hardening — Tasks

## Task 1: HTTP Cleartext
- [ ] Thêm `android:usesCleartextTraffic="true"` vào `<application>` trong `AndroidManifest.xml`
- [ ] Tạo `res/xml/network_security_config.xml` với `<domain-config cleartextPermitted="true">`
- [ ] Ref `<network-security-config>` trong `AndroidManifest.xml`

## Task 2: Target SDK 36
- [ ] Đổi `compileSdk 34` → `compileSdk 36`
- [ ] Đổi `targetSdk 34` → `targetSdk 36`
- [ ] Verify AGP 8.1.0 tương thích (đã OK)
- [ ] Build pass trên GH Actions

## Task 3: Sentry SDK
- [ ] Thêm `sentry_flutter: ^8.0.0` vào `pubspec.yaml`
- [ ] Init `SentryFlutter.init()` trong `lib/main.dart`
- [ ] Config `FlutterError.onError` + `PlatformDispatcher.instance.onError`
- [ ] Verify `flutter pub get` pass
- [ ] Build pass trên GH Actions
