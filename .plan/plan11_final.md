# plan11_final.md — Chỉ thị kỹ thuật tổng hợp cuối cùng

**Nguồn:** đối chiếu `plan11.md`, `plan11_review1.md`, `plan11_review2.md`, `plan11_review3.md`, `plan11_review4.md` .

**Trạng thái xác nhận trong source (đã verify trực tiếp, không suy đoán):**

| Hạng mục | File | Trạng thái |
|---|---|---|
| Theme | `lib/main.dart:79-84` | `MaterialApp` chỉ có `theme: ThemeData(...)`, không `darkTheme`, không `themeMode` |
| IME guard | `android/.../SmartClipboardIME.kt:168-176` | `onStartInput`/`onStartInputView` không hề check `EditorInfo.inputType`, không có `requestHideSelf()` ở bất kỳ đâu trong file |
| History unfocus | `lib/screens/clipboard/clipboard_history_screen.dart` | Có `TextField` (search), không có `unfocus()`/`FocusScope` |
| Free limits | `lib/core/constants/app_limits.dart` | `freeClipboardLimit=50`, `freeActiveSnippets=15`, `freeFolderLimit=3` còn nguyên |
| Enforce logic | `clipboard_repository.dart`, `snippet_repository.dart` | `enforceFreeLimit()`, `_enforceSnippetFreeLimit()`, `canCreateFolder()` còn hoạt động |
| Pro status | `lib/state/providers.dart:372` | `proStatusProvider = StateProvider<bool>((_) => false)` — chỉ là bool stub, không có expiry |
| Ads infra | `lib/core/constants/app_config.dart` | Đã có `rewardedAdUnitId` (test/prod), chưa có `RewardedAdService`/entitlement flow |
| Search/Favorite/Filter | `clipboard_history_screen.dart`, `providers.dart` | **Đã hoạt động đầy đủ** — KHÔNG được đụng vào |

Cả 5 nguồn phân tích (agent gốc `plan11.md` + 4 review) đều bám sát source thật. Điểm bất đồng duy nhất là mô hình thời hạn Pro (calendar day vs rolling 24h) — đã được chốt bên dưới ở Mục 3.

---

## Mục 1 — IME Lifecycle Guard (P0, ưu tiên cao nhất)

### Vấn đề gốc
`onStartInputView()` hiện coi bất kỳ lần Android gọi lại là "keyboard đang active" và set `isKeyboardVisible = true`, `loadCache()`, mà không xác nhận `EditorInfo` có thực sự là một text editor hợp lệ hay không. Đây là root cause khiến keyboard bật sai khi thao tác trong History (archive/delete/favorite), vì search `TextField` vẫn giữ focus và Android re-trigger lifecycle của IME.

### Nguyên tắc thiết kế
> SmartClipboardIME chỉ được phép hiển thị keyboard khi Android cung cấp một `EditorInfo`/`InputConnection` hợp lệ cho một editable input field. IME không được biết và không được dựa vào việc Flutter đang ở route/tab nào.

Không dùng rule "trong app SmartClipboard thì luôn tắt keyboard" — vì Snippet Edit và History Search vẫn cần bàn phím hoạt động bình thường.

### Native — `SmartClipboardIME.kt`

```kotlin
private fun isEditableTextField(info: EditorInfo?): Boolean {
    if (info == null) return false
    val cls = info.inputType and InputType.TYPE_MASK_CLASS
    if (cls == InputType.TYPE_NULL) return false
    return cls == InputType.TYPE_CLASS_TEXT
        || cls == InputType.TYPE_CLASS_NUMBER
        || cls == InputType.TYPE_CLASS_PHONE
        || cls == InputType.TYPE_CLASS_DATETIME
}

override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
    super.onStartInput(info, restarting)
    if (!isEditableTextField(info)) {
        requestHideSelf(0)
        return
    }
    // Giữ nguyên logic hiện có (finishComposingText cho leftover composing region)
    currentInputConnection?.finishComposingText()
}

override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
    if (!isEditableTextField(info)) {
        requestHideSelf(0)
        return
    }
    super.onStartInputView(info, restarting)
    currentEditorInfo = info
    typingBuffer.clear()
    isKeyboardVisible = true
    loadCache()
    handler.removeCallbacks(pollRunnable)
    handler.postDelayed(pollRunnable, POLL_INTERVAL_MS)
    updateSuggestions("")
}
```

**Lưu ý kỹ thuật quan trọng (rút ra từ đọc source thật):**
- Guard đặt ở `onStartInput` (trước khi `onCreateInputView` được gọi bởi framework) để tránh chi phí xử lý thừa, nhưng vẫn phải guard lại ở `onStartInputView` — defense in depth, vì hai callback không đảm bảo luôn đi cùng nhau qua mọi phiên bản Android.
- `currentEditorInfo` chỉ được set **trong nhánh hợp lệ**. Nếu guard reject sớm mà vẫn set field này, các hàm khác đang dựa vào nó (`isPasswordField()`, `shouldAutoCapitalize()`) có thể đọc phải editor info cũ/stale và gây sai logic ở lần gõ tiếp theo.
- `onFinishInput()` giữ nguyên logic reset `currentEditorInfo = null` hiện có — không cần sửa.
- Không sửa `onCreateInputView()` trong batch này (rủi ro cao, không cần thiết để fix bug), nhưng nên thêm comment ghi rõ: view được inflate không đồng nghĩa keyboard nên hiển thị — để tránh agent sau này hiểu nhầm.

### Flutter — History & Snippet screens

Trước mọi action archive / delete / toggle-favorite / pin trong `ClipboardHistoryScreen` và `SnippetsScreen`:

```dart
FocusManager.instance.primaryFocus?.unfocus();
```

**Lý do bắt buộc làm cả 2 phía:** chỉ sửa Flutter không đủ vì IME là system component độc lập tiến trình, có thể được Android khởi động lại độc lập với việc Flutter có unfocus hay không. Chỉ sửa Native thì gần đủ nhưng vẫn nên làm cả Flutter để giảm số lần IME lifecycle bị trigger không cần thiết (tối ưu, không phải correctness).

### Test matrix bắt buộc

| Thao tác | Kết quả mong đợi |
|---|---|
| History: archive item | Keyboard KHÔNG hiện |
| History: delete item | Keyboard KHÔNG hiện |
| History: toggle favorite | Keyboard KHÔNG hiện |
| History: tap vào ô Search | Keyboard HIỆN |
| Snippet: create/edit Title/Content field | Keyboard HIỆN |
| Snippet: list screen (không tap field nào) | Keyboard KHÔNG hiện |
| Settings screen | Keyboard KHÔNG hiện |
| Chrome: tap vào address bar / text field | Keyboard HIỆN (regression check — IME vẫn hoạt động bình thường ngoài app) |
| Gmail: compose | Keyboard HIỆN |

---

## Mục 2 — Gỡ bỏ Free Limits (P0)

### Nguyên tắc
Không đổi hằng số thành `999999` — đó là giải pháp tồi, để lại dead logic dễ bị dùng lại nhầm sau này. Phải **xoá triệt để** cả constants lẫn hàm enforce.

### Việc cần làm

**`lib/core/constants/app_limits.dart`**
- Xoá: `freeClipboardLimit`, `freeActiveSnippets`, `freeFolderLimit`.
- Giữ nguyên: `expirationOptionsDays`, `sensitiveAutoDeleteHours`, `defaultTriggerPrefix`, `expansionDelimiters` (đây là app constants thật, không liên quan monetization).

**`lib/repositories/clipboard_repository.dart`**
- Xoá hoàn toàn hàm `enforceFreeLimit()`.
- Xoá field `archivedCount` khỏi class `ClipboardSaveResult` — đây là dead reference nếu chỉ xoá hàm mà để lại field, code gọi nơi khác (banner "Nâng cấp Pro") vẫn tưởng cần xử lý.
- Xoá lời gọi `enforceFreeLimit()` trong `save()`.

**`lib/repositories/snippet_repository.dart`**
- Xoá hoàn toàn `_enforceSnippetFreeLimit()` (dòng ~126, vòng lặp `while (active > AppLimits.freeActiveSnippets)`).
- Xoá hoàn toàn `canCreateFolder()` (dòng ~154) — xoá hàm, không phải sửa để luôn `return true`.

**`lib/screens/snippets/folders_screen.dart`**
- Xoá đoạn copy "Bản Free tối đa X folders..." (dòng ~61) và toàn bộ UI logic phụ thuộc vào giới hạn folder.

### Migration dữ liệu đã archive

Đây là bước dễ bị bỏ sót nhưng **bắt buộc**: nếu chỉ gỡ limit mà không khôi phục dữ liệu cũ đã bị archive do vượt quota, user sẽ thấy "được unlimited nhưng dữ liệu cũ biến mất đâu".

```
app_meta.limits_model_version (int, default = 1)

Khi app khởi động và limits_model_version < 2:
  1. UPDATE clipboard_items SET is_archived = 0 WHERE is_archived = 1
  2. UPDATE snippets SET is_archived = 0 WHERE is_archived = 1
  3. SET limits_model_version = 2
  4. Gọi CacheSyncService(db).regenerateSnippetCache()
```

**Chỉ chạy một lần** (kiểm tra version marker), KHÔNG chạy `restoreAllArchived()` mỗi lần app khởi động — sẽ tốn tài nguyên vô ích và có thể phục hồi nhầm dữ liệu mà user đã archive thủ công (nếu tính năng này tồn tại riêng biệt trong tương lai).

---

## Mục 3 — Rewarded Pro: Rolling 24h (P0)

### Quyết định: Rolling 24h, KHÔNG dùng calendar day

**Bối cảnh tranh luận:** `plan11.md` (agent gốc) đề xuất calendar day (hết hạn 23:59:59 cùng ngày) vì bám sát nghĩa đen "dùng trong ngày". Cả 4 bản review đều phản đối và chọn rolling 24h.

**Lý do chốt rolling 24h (không chỉ vì đa số đồng thuận):**
1. Calendar day tạo UX tệ ở biên: xem ad lúc 23:50 chỉ được ~10 phút Pro — user cảm thấy bị lừa, có thể học được thói quen tránh xem ads gần cuối ngày (giảm hiệu quả ad revenue).
2. "Dùng trong ngày" là ngôn ngữ mô tả trải nghiệm tự nhiên, không phải spec kỹ thuật đòi hỏi đúng khung 00:00–23:59. Rolling 24h vẫn thoả mãn cảm nhận này ở đại đa số trường hợp sử dụng thực tế.
3. Lưu UTC epoch millis + rolling 24h loại bỏ hoàn toàn lớp bug timezone/DST khi user đổi múi giờ thiết bị — calendar day theo local time sẽ vướng edge case này.

### Kiến trúc: EntitlementService làm single source of truth

Không rải `ref.watch(proStatusProvider)` khắp code (như hiện tại). Thay bằng service tập trung để sau này dễ đổi từ Rewarded Ad sang IAP/subscription mà không phải sửa toàn app.

```dart
class EntitlementService {
  // Lưu trong app_meta, key: 'pro_expiry' — giá trị: UTC epoch millis (int)

  Future<void> unlockFromRewardedAd() async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 24));
    await _saveProExpiry(expiry.millisecondsSinceEpoch);
  }

  Future<bool> get isProActive async {
    final expiryMs = await _getProExpiry();
    if (expiryMs == null) return false;
    return DateTime.now().toUtc().millisecondsSinceEpoch < expiryMs;
  }

  Future<DateTime?> get expiresAt async {
    final expiryMs = await _getProExpiry();
    if (expiryMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiryMs, isUtc: true);
  }
}
```

Provider chỉ expose service/state ra ngoài, không tự chứa logic tính toán:

```dart
final entitlementServiceProvider = Provider((ref) => EntitlementService(ref.watch(databaseProvider)));
final isProActiveProvider = FutureProvider((ref) => ref.watch(entitlementServiceProvider).isProActive);
```

Xoá `proStatusProvider = StateProvider<bool>((_) => false)` khỏi `providers.dart` — thay toàn bộ chỗ dùng bằng `isProActiveProvider`.

### Rewarded Ad integration

`AppConfig` đã có sẵn `enableAds`, `testAds`, `rewardedAdUnitId` — chỉ thiếu service load/show:

```dart
class RewardedAdService {
  Future<void> showAd({
    required VoidCallback onEarned,
    required VoidCallback onFailed,
  }) async {
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show(onUserEarnedReward: (_, __) => onEarned());
        },
        onAdFailedToLoad: (_) => onFailed(),
      ),
    );
  }
}
```

Khi `onEarned()` được gọi → `entitlementService.unlockFromRewardedAd()`.

### UI Settings — section "Pro"

- **Locked:** "✨ Unlock Pro for today — Watch a short ad to unlock all Pro features for 24 hours" + nút **Watch Ad**.
- **Active:** "✨ Pro unlocked — Available until [giờ local, tính từ expiresAt UTC]" + danh sách feature đang bật.
- **Hết hạn:** quay lại trạng thái Locked, không tự động nhắc lại (tránh làm phiền).
- **Rule:** 1 lần xem ad = trọn 24h Pro. KHÔNG bắt xem ad lại mỗi lần dùng tính năng Pro trong lúc còn active.

### Trước khi code: chốt danh sách tính năng Pro

Cần liệt kê ngắn gọn feature nào thực sự gated sau Pro (export, advanced privacy, v.v.) — nếu không, nút "Watch Ad to Unlock" sẽ không gắn với hành vi cụ thể nào trong app, làm giảm giá trị cảm nhận của Pro.

### Test matrix

| Thao tác | Kết quả mong đợi |
|---|---|
| Xem ad thành công | Pro active, đúng 24h kể từ thời điểm xem |
| Đóng app, mở lại trong 24h | Pro vẫn active |
| Đóng app, mở lại sau 24h | Pro locked, có thể xem ad lại |
| Xem ad lúc 23:50 | Pro active đủ 24h (không bị cắt ở nửa đêm) |
| Đổi timezone thiết bị trong lúc Pro active | Không ảnh hưởng thời hạn thực tế (vì so sánh UTC) |

---

## Mục 4 — Theme System: Light / Dark / System (P1)

### Kiến trúc

```
AppThemeMode { system, light, dark }
      ↓
ThemeController (tách riêng khỏi AppSettingsController — theme là
                 application-wide concern, không phải setting của clipboard)
      ↓
persist vào app_meta, key: 'app_theme_mode'
      ↓
MaterialApp(themeMode: ..., theme: lightTheme, darkTheme: darkTheme)
```

### Flutter — `main.dart`

```dart
return MaterialApp(
  title: 'Smart Clipboard',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorSchemeSeed: const Color(0xFF3D5AFE),
    brightness: Brightness.light,
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorSchemeSeed: const Color(0xFF3D5AFE),
    brightness: Brightness.dark,
    useMaterial3: true,
  ),
  themeMode: ref.watch(themeModeProvider), // ThemeMode.system/light/dark
  // ... phần còn lại giữ nguyên
);
```

### Settings UI

Thêm section mới **Appearance > Theme** trong `SettingsScreen` (bên cạnh Auto delete, Pause logging, Biometric, Backup/Restore, Language, Keyboard background, Metrics đã có) với 3 lựa chọn radio: System / Light / Dark.

### Đồng bộ xuống Native IME

**Vấn đề:** `SmartClipboardIME.kt` hiện có `isDarkMode()` dựa vào `resources.configuration.uiMode` — tức là follow **Android system dark/light**, không follow lựa chọn theme trong app. Nếu user chọn App Theme = Dark nhưng Android System = Light, keyboard sẽ sai màu.

**Giải pháp MVP (đủ dùng, không cần over-engineer):**
1. Flutter ghi giá trị theme vào file cache mà IME đã đọc sẵn (`snippets_cache.json` hoặc SharedPreferences native cùng cơ chế `keyboard_bg_color` đang có ở dòng `keyboardBgColorHex` trong `loadCache()`).
2. IME đọc lại giá trị này trong `loadCache()` (đã được gọi trong `onStartInputView()`) để áp palette tương ứng — không cần broadcast realtime, sync khi keyboard mở lại lần tiếp theo là đủ.
3. Custom keyboard background color (`keyboard_bg_color`) đã có sẵn từ trước — theme app chỉ là **giá trị mặc định** khi user chưa custom màu riêng, không ghi đè lên custom color đã chọn.

---

## Phạm vi KHÔNG được đụng vào

Source hiện đã có đầy đủ và hoạt động tốt — nếu giao lại các phần này, agent sẽ code trùng lặp, gây conflict:

- Favorite star rendering trong `ClipboardHistoryScreen` (`item.isFavorite ? Icons.star : Icons.star_border`)
- Search trong History
- Favorites/Pinned filter trong History
- Search/filter provider của Snippet (search title, trigger, content, enabled/disabled, folder) trong `providers.dart`

---

## Thứ tự triển khai

| Ưu tiên | Việc | Lý do thứ tự |
|---|---|---|
| **P0-1** | Mục 1 — IME Lifecycle Guard | Bug UX nghiêm trọng nhất, độc lập nhất về mặt kỹ thuật (chỉ native + 1 dòng Flutter), nên fix trước để có thể release riêng nếu cần |
| **P0-2** | Mục 2 — Gỡ Free Limits + Migration | Không phụ thuộc Mục 1, có thể làm song song, nhưng nên xong trước Mục 3 vì Mục 3 cần trạng thái "unlimited" làm nền |
| **P0-3** | Mục 3 — Rewarded Pro rolling 24h | Phụ thuộc gián tiếp vào Mục 2 (khái niệm Pro thay thế hoàn toàn Free limit cũ) |
| **P1** | Mục 4 — Theme System | Ít rủi ro nhất, không ảnh hưởng data/monetization, làm sau cùng |

## Yêu cầu báo cáo

Cung cấp diff chi tiết theo từng file đã sửa, theo đúng thứ tự 1 → 2 → 3 → 4. Với Mục 1, bắt buộc chạy qua test matrix và báo kết quả từng dòng trước khi coi là hoàn thành.