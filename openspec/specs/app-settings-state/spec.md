# App Settings State Specification

## Purpose

Settings toàn cục của app (expiration days, pause capture, biometric lock, onboarding done) được persist vào bảng `app_meta` qua `MetaDao` và expose ra UI bằng một StateNotifier Riverpod duy nhất — thống nhất với nguyên tắc "Riverpod toàn app, không setState tự do ở màn hình chính".

## Requirements

### Requirement: Load một lần lúc khởi động

`AppSettingsController` (file: `lib/state/providers.dart`) constructor gọi `_load()` async đọc 4 key từ app_meta; trong khi load, state mặc định có `loaded = false` — RootGate hiển thị splash thay vì flash nháy HomeScreen/Onboarding sai.

#### Scenario: Khởi động app
- **GIVEN** app_meta có expiration_days=7, biometric_lock=1, onboarding_done=1
- **WHEN** controller khởi tạo rồi _load() hoàn tất
- **THEN** state = AppSettings(expirationDays: 7, biometricLock: true, onboardingDone: true, loaded: true).

#### Scenario: Giá trị expiration không hợp lệ trong DB
- **GIVEN** expiration_days = 99 (ngoài [1,7,30])
- **WHEN** _load()
- **THEN** fallback về 30 (phần tử cuối danh sách hợp lệ).

### Requirement: Mọi setter persist trước khi đổi state

`setExpirationDays`, `setCapturePaused`, `setBiometricLock`, `completeOnboarding`: ghi app_meta TRƯỚC, sau đó mới `state = state.copyWith(...)`. Không có setter nào chỉ đổi state mà không persist.

#### Scenario: Bật pause mode
- **WHEN** `setCapturePaused(true)`
- **THEN** app_meta('capture_paused') = '1' trước khi UI rebuild; mọi consumer watch appSettingsProvider thấy giá trị mới.

### Requirement: RootGate routing dựa trên settings

Thứ tự quyết định màn hình gốc: `!loaded` → splash → `!onboardingDone` → OnboardingScreen → `biometricLock` → LockGate(HomeScreen) → HomeScreen.

#### Scenario: Settings mới cài chưa load xong
- **WHEN** build RootGate ngay frame đầu
- **THEN** chỉ thấy CircularProgressIndicator — không flash Onboarding/Home.

## Cần làm rõ

- Settings KHÔNG nằm trong payload backup/restore (app_meta bị loại) → sau restore, user phải bật lại biometric/pause/expiration thủ công. Có chủ đích (tránh restore lock khiến user mất quyền vào app trên máy khác) hay thiếu sót?
- `proStatusProvider` là StateProvider stub `false`, không liên kết gì với setting/IAP — thuộc phạm vi wire-up IAP tương lai.
