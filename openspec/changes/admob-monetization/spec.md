# AdMob Monetization

## Overview

Tích hợp Google AdMob SDK vào Flutter app để kiếm tiền ads trên Play Store và Apple Store. Banner ads hiển thị ở bottom của các main screens. Tất cả ads nằm trong vùng safe area để không bị che khuất bởi Android 3-button navigation bar.

---

## 1. AdMob SDK Integration

### Package
```yaml
dependencies:
  google_mobile_ads: ^5.2.0
```

### Config Flag
Tạo `lib/core/constants/app_config.dart`:
```dart
class AppConfig {
  AppConfig._();
  static const bool testAds = true;  // flip to false khi release production
  // Test AdMob App IDs (Google cung cấp để test)
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';
  // Test Banner Ad Unit IDs
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  // Production Ad Unit IDs (điền sau khi tạo trên AdMob console)
  static const String prodBannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static String get bannerAdUnitId => testAds ? testBannerAdUnitId : prodBannerAdUnitId;
}
```

### Platform Setup

**Android** (`AndroidManifest.xml`):
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511711"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

### Initialization
Trong `lib/main.dart`, sau `WidgetsFlutterBinding.ensureInitialized()`:
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ...
await MobileAds.instance.initialize();
```

---

## 2. Banner Ad Widget

Tạo reusable widget `lib/widgets/banner_ad_widget.dart`:
- Load banner ad với `BannerAd` + `AdListener`
- Handle `onFailedToLoad` — ẩn widget thay vì crash
- Handle `onLoaded` — hiển thị `AdWidget`
- Size: `AdSize.banner` (320x50) — chuẩn, không quá lớn

### Scenario: Banner load thành công
- **GIVEN** `AppConfig.testAds = true`
- **WHEN** screen mount
- **THEN** banner test ad hiển thị ở bottom

### Scenario: Banner load fail
- **GIVEN** network timeout hoặc no-fill
- **WHEN** `onFailedToLoad` callback
- **THEN** widget trả `SizedBox.shrink()` — không hiển thị gì, không crash

---

## 3. Ad Placement

Banner ads hiển thị ở **bottom** của các screens chính, TRÊN NavigationBar (không overlap):

### Screens có ads:
| Screen | Vị trí | Widget |
|--------|--------|--------|
| `ClipboardHistoryScreen` | Bottom of body (trước NavigationBar) | BannerAdWidget |
| `SnippetsScreen` | Bottom of body (trước NavigationBar) | BannerAdWidget |
| `SettingsScreen` | Bottom of ListView | BannerAdWidget |

### Screens KHÔNG có ads:
- `PlaygroundScreen` — đang test tính năng, ads gây rối
- `SnippetEditScreen` — editor, ads chiếm chỗ
- `OnboardingScreen` — onboarding flow
- Lock screen

---

## 4. Android 3-Button Navigation Safe Area

### Vấn đề
Android 3-button navigation bar (Back/Home/Recent) che khuất bottom 48dp của app. Nếu ads hoặc content render ở very bottom → bị che.

### Giải pháp

**HomeScreen** — `NavigationBar` hiện tại đã đúng (Flutter `NavigationBar` tự respect system insets). KHÔNG cần thay đổi.

**Banner ads** — Widget `BannerAdWidget` wrap trong `SafeArea(bottom: true)` hoặc đặt TRÊN `NavigationBar` trong widget tree (không phải trong `IndexedStack` children).

**Architecture hiện tại** (`HomeScreen`):
```dart
Scaffold(
  body: Column(children: [
    _KeyboardEnableBanner(),  // conditional
    Expanded(child: IndexedStack(children: [
      ClipboardHistoryScreen(),  // ← ads ở đây
      SnippetsScreen(),
      PlaygroundScreen(),
      SettingsScreen(),
    ])),
  ]),
  bottomNavigationBar: NavigationBar(...),  // ← TRƯỚC ads
)
```

**Cách fix**: Banner ads đặt trong `Column` SAU `IndexedStack`, TRƯỚC `NavigationBar`:
```dart
Scaffold(
  body: Column(children: [
    _KeyboardEnableBanner(),
    Expanded(child: IndexedStack(...)),
    BannerAdWidget(),  // ← BETWEEN content and nav bar
  ]),
  bottomNavigationBar: NavigationBar(...),
)
```

Hoặc đơn giản hơn: mỗi screen tự render `BannerAdWidget` ở cuối `body` — nhưng đảm bảo nó KHÔNG nằm trong `ListView` (vì ListView scroll thì ads biến mất). Thay vào đó, dùng `Column` + `Expanded(ListView)` + `BannerAdWidget` ở cuối.

### Scenario: Ads không bị che bởi 3-button nav
- **GIVEN** device dùng Android 3-button navigation
- **WHEN** render banner ad
- **THEN** banner hiển thị hoàn toàn visible, không bị nav bar che

### Scenario: Gesture navigation (gesture bar mỏng)
- **GIVEN** device dùng gesture navigation
- **WHEN** render banner ad
- **THEN** banner hiển thị đúng, không overlap gesture bar

---

## 5. L10n Keys

Không cần l10n mới — ads là visual widget, không có text cần dịch.

---

## Files Ảnh Hưởng

```
lib/core/constants/app_config.dart       — MỚI: test_ads flag + ad unit IDs
lib/main.dart                            — THÊM: MobileAds.instance.initialize()
lib/widgets/banner_ad_widget.dart        — MỚI: reusable banner ad widget
lib/screens/home_screen.dart             — SỬA: thêm BannerAdWidget vào Column
lib/screens/clipboard/clipboard_history_screen.dart — SỬA: wrap body trong Column với BannerAdWidget
lib/screens/snippets/snippets_screen.dart          — SỬA: wrap body trong Column với BannerAdWidget
lib/screens/settings/settings_screen.dart          — SỬA: thêm BannerAdWidget ở cuối ListView
android/app/src/main/AndroidManifest.xml          — SỬA: thêm AdMob meta-data
pubspec.yaml                                     — SỬA: thêm google_mobile_ads
```

---

## Cần làm rõ
- Không có thay đổi l10n nào — ads là visual widget thuần túy
- `test_ads = true` flag kiểm soát: dùng test ad unit IDs (Google cung cấp) thay vì production IDs
- Khi flip `test_ads = false`, cần tạo ad units trên AdMob console và điền production IDs
