# AdMob Monetization — Tasks

## Task 1: Config & SDK Setup
- [x] Thêm `google_mobile_ads: ^5.2.0` vào `pubspec.yaml`
- [x] Thêm AdMob `APPLICATION_ID` meta-data vào `AndroidManifest.xml`
- [ ] Cập nhật `app_config.dart`: `enableAds=false` + real ad IDs
- [ ] Init `MobileAds.instance.initialize()` conditional trong `lib/main.dart`

## Task 2: Banner Ad Widget
- [x] Tạo `lib/widgets/banner_ad_widget.dart` — reusable widget
- [ ] Cập nhật: check `enableAds` trước khi load ad
- [ ] Handle `onLoaded` / `onFailedToLoad` / `onDismissed`

## Task 3: Ad Placement — Screens
- [x] `HomeScreen` — thêm `BannerAdWidget()` vào Column (giữa IndexedStack và NavigationBar)
- [ ] `ClipboardHistoryScreen` — wrap body trong Column + BannerAdWidget
- [ ] `SnippetsScreen` — wrap body trong Column + BannerAdWidget
- [ ] `SettingsScreen` — thêm BannerAdWidget ở cuối ListView

## Task 4: Safe Area — Android 3-Button Nav
- [ ] Verify NavigationBar tự respect system insets (Flutter default)
- [ ] Verify BannerAdWidget render TRÊN NavigationBar, không overlap
- [ ] Verify content không bị che bởi 3-button nav bar
- [ ] Test trên device có 3-button navigation

## Task 5: Build & Verify
- [ ] `flutter pub get` pass
- [ ] Build pass trên GH Actions
- [ ] APK cài trên device: ads hiển thị, không overlap nav bar
