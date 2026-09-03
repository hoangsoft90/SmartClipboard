# Smart Clipboard — Remediation Plan (plan12_final.md)

> Tổng hợp cuối cùng từ `plan12.md` + `plan12_review1.md` (bao gồm checklist
> audit). Toàn bộ 6 mục dưới đây đã **verify trực tiếp trên source hiện tại**
> — không suy đoán. Ưu tiên theo effort tăng dần và mức độ chắc chắn giảm
> dần: Restore + Dedup trước (đã có patch chính xác), Signing + Pro gate sau
> (cần vài quyết định nhỏ), Privacy/Ads là quyết định sản phẩm cần bạn chốt
> trước khi agent code.

**Không làm trong đợt remediation này:** Vietnamese/Telex (đã đóng băng có
chủ đích từ batch 8, giữ nguyên), IME layout/composition, thêm feature mới.
Đây là đợt **dọn nợ kỹ thuật**, không phải đợt phát triển tính năng.

---

## 1. Backup Restore — 100% sẽ crash, sửa native, không đụng Dart

### Xác nhận qua code (trace toàn bộ đường đi)

```kotlin
// MainActivity.kt
val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)...  // luôn trả về content:// URI
filePickerResult?.success(uri.toString())            // trả thẳng "content://..." cho Flutter
```
```dart
// backup_service.dart
final file = File(path);        // path = "content://..."
await file.readAsString();      // dart:io không hiểu content:// → FileSystemException
```

**Đây không phải "có khả năng lỗi"** — `ACTION_OPEN_DOCUMENT` luôn trả về
`content://` URI trên Android hiện đại, không bao giờ trả filesystem path
thật. Restore **chắc chắn crash** với mọi file user chọn.

### Fix — copy nội dung URI ra file thật ở phía native, KHÔNG đụng `backup_service.dart`

**File:** `MainActivity.kt`

```kotlin
filePickerLauncher = registerForActivityResult(
    ActivityResultContracts.StartActivityForResult()
) { result ->
    if (result.resultCode == Activity.RESULT_OK) {
        val uri = result.data?.data
        if (uri != null) {
            // ✅ FIX: copy nội dung content:// URI ra file thật trong cacheDir,
            // trả về ABSOLUTE PATH thay vì content:// URI — dart:io File() chỉ
            // hiểu filesystem path, không hiểu content URI scheme.
            val realPath = copyUriToCacheFile(uri)
            filePickerResult?.success(realPath)
        } else {
            filePickerResult?.success(null)
        }
    } else {
        filePickerResult?.success(null)
    }
    filePickerResult = null
}

/**
 * Đọc nội dung content:// URI qua ContentResolver (cách duy nhất đúng trên
 * Android cho URI từ SAF picker) và copy ra 1 file tạm trong cacheDir để
 * Flutter (dart:io File) đọc được bằng path thông thường.
 */
private fun copyUriToCacheFile(uri: android.net.Uri): String? {
    return try {
        val inputStream = contentResolver.openInputStream(uri) ?: return null
        val tempFile = java.io.File(cacheDir, "restore_import_${System.currentTimeMillis()}.scbak")
        inputStream.use { input ->
            tempFile.outputStream().use { output -> input.copyTo(output) }
        }
        tempFile.absolutePath
    } catch (e: Exception) {
        null
    }
}
```

**Không cần sửa `backup_service.dart`** — hàm `restoreFrom(path, passphrase)`
tiếp tục nhận đúng 1 filesystem path bình thường như thiết kế ban đầu, chỉ
khác là path này giờ trỏ tới file tạm đã copy, không phải content URI gốc.

`cacheDir` được hệ điều hành tự dọn định kỳ — không cần code thêm logic xoá
file tạm cho MVP, chấp nhận được.

### Test

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Export backup, sau đó Restore chọn đúng file `.scbak` vừa export | Restore thành công, dữ liệu khôi phục đúng |
| 2 | Chọn nhầm file không phải `.scbak` (vd ảnh) | Báo lỗi "không phải file backup", không crash app |
| 3 | Chọn file backup nhưng nhập sai passphrase | Báo lỗi giải mã, không crash |

---

## 2. Dedup không tăng `copy_count` — bug đã bị bỏ sót 2 lần liên tiếp

### Xác nhận — đây là lần thứ 3 bug này được chỉ ra

Comment ngay phía trên code đã ghi đúng ý định từ đầu, nhưng code thực thi
không khớp:

```dart
/// true nếu trùng hash → chỉ UPDATE last_used_at + copy_count+1 (mục 2.1).
...
await db.update(
  'clipboard_items',
  {'last_used_at': now, 'updated_at': now},   // ❌ thiếu copy_count, is_archived
  where: 'id = ?', whereArgs: [id],
);
```

**Bổ sung phát hiện mới:** ngoài thiếu `copy_count`, nhánh dedup cũng không
reset `is_archived` — nếu item đã bị archive (do restore Pro chưa gọi, hoặc
lý do khác) và user copy lại đúng nội dung, item vẫn ẩn khỏi History dù vừa
"dùng lại".

### Fix — đúng vị trí, đúng 1 lần

**File:** `clipboard_repository.dart`, hàm `save()`, nhánh dedup

```dart
if (existing.isNotEmpty) {
  final id = existing.first['id'] as String;
  // ✅ FIX: dùng rawUpdate để tăng copy_count trực tiếp trong SQL (atomic,
  // tránh race đọc-rồi-ghi), đồng thời unarchive nếu item từng bị ẩn.
  await db.rawUpdate(
    'UPDATE clipboard_items SET last_used_at = ?, updated_at = ?, '
    'copy_count = copy_count + 1, is_archived = 0 WHERE id = ?',
    [now, now, id],
  );
  final item = ClipboardItem.fromMap((await db.query('clipboard_items',
          where: 'id = ?', whereArgs: [id], limit: 1))
      .first);
  return ClipboardSaveResult(item: item, wasDeduplicated: true);
}
```

### Test

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Copy 1 đoạn text, kiểm tra `copy_count = 1` trong DB | Đúng |
| 2 | Copy lại đúng đoạn text đó lần 2 | `copy_count = 2`, `last_used_at` cập nhật |
| 3 | Archive 1 item, sau đó copy lại đúng nội dung đó | Item xuất hiện lại trong History (is_archived = 0) |

---

## 3. Release build ký bằng debug keystore

### Xác nhận

```gradle
buildTypes { release { signingConfig signingConfigs.debug } }
```

### Fix — tạo keystore thật, không hardcode credential vào git

**Bước 1 — tạo keystore (chạy 1 lần, ngoài code, lưu ngoài repo):**
```bash
keytool -genkey -v -keystore ~/smart-clipboard-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias smart_clipboard
```

**Bước 2 — file mới `android/key.properties`** (thêm vào `.gitignore`, KHÔNG
commit):
```properties
storePassword=<mật khẩu keystore>
keyPassword=<mật khẩu key>
keyAlias=smart_clipboard
storeFile=/đường/dẫn/tuyệt/đối/tới/smart-clipboard-release.jks
```

**Bước 3 — `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
    buildTypes {
        release {
            signingConfig keystoreProperties.isEmpty()
                ? signingConfigs.debug   // fallback cho máy dev chưa có key.properties
                : signingConfigs.release
        }
    }
}
```

**Lưu ý cho agent:** không tự tạo keystore trong lúc code — đây là bước thủ
công 1 lần, bạn (chủ dự án) chạy trên máy mình, KHÔNG giao cho AI coding
agent thực hiện, để giữ private key không lọt vào bất kỳ log/output nào của
agent.

---

## 4. Pro không gate bất kỳ tính năng nào — thêm gate tối thiểu, cụ thể

### Xác nhận — grep toàn bộ project

`isProActiveProvider` chỉ xuất hiện ở `providers.dart` (định nghĩa) và
`settings_screen.dart` (hiển thị) — không có nơi nào khác tham chiếu.
`BannerAdWidget` được nhúng thẳng, không điều kiện, trong `home_screen.dart`.

### Fix tối thiểu — ẩn banner ads khi Pro active

Đây là gate **cụ thể, đo lường được, rủi ro thấp nhất** để "xem ads mở Pro"
có ý nghĩa thật ngay lập tức, không cần thiết kế lại toàn bộ monetization:

**File:** `home_screen.dart`

```dart
// Trước:
const BannerAdWidget(),

// Sau:
Consumer(
  builder: (context, ref, _) {
    final isProAsync = ref.watch(isProActiveProvider);
    final isPro = isProAsync.value ?? false;
    if (isPro) return const SizedBox.shrink();
    return const BannerAdWidget();
  },
),
```

### Quyết định sản phẩm cần bạn chốt (agent không tự quyết được)

Ẩn banner ads là gate tối thiểu để "Pro có nghĩa", nhưng đây rõ ràng chưa
phải giá trị Pro đầy đủ. Cần bạn chốt thêm ít nhất 1-2 tính năng Pro thật sự
(ví dụ: Dynamic Variables trong snippet — đã có trong Master Spec gốc như
tính năng P2, hoặc export không giới hạn định dạng) trước khi quảng cáo rộng
rãi "Pro" trong app — nếu không, banner-only vẫn là giá trị khá mỏng.
**Không đưa việc chọn feature Pro vào phạm vi patch này** — đây là quyết định
sản phẩm, để riêng.

### Test

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Chưa unlock Pro, mở Home | Banner ads hiển thị |
| 2 | Xem rewarded ad, unlock Pro | Banner biến mất ngay |
| 3 | Đợi hết 24h (hoặc set giờ hệ thống lùi để test) | Banner xuất hiện lại |

---

## 5. Privacy claim mâu thuẫn Manifest — quyết định sản phẩm, 2 hướng

### Xác nhận

```xml
<!-- Network permission — cần cho AdMob SDK + Sentry SDK -->
<uses-permission android:name="android.permission.INTERNET" />
android:usesCleartextTraffic="true"
```
Comment trong chính Manifest tự thừa nhận lý do — đây là hệ quả có chủ đích
từ việc thêm AdMob/Sentry ở batch trước (plan11), nhưng chưa có ai cập nhật
lại onboarding privacy claim cho khớp. **Đây KHÔNG phải bug 1 dòng, mà là 1
quyết định sản phẩm bạn cần chốt trước khi giao agent** — 2 hướng dưới đây
loại trừ lẫn nhau, không làm nửa vời cả hai.

### Hướng A — Giữ đúng lời hứa Privacy-first tuyệt đối

- Bỏ `sentry_flutter` khỏi `pubspec.yaml` + `main.dart`.
- Bỏ `google_mobile_ads` — đồng nghĩa **bỏ luôn cơ chế Rewarded Ad → Pro
  24h** (mục 3 và 4 ở trên sẽ vô nghĩa, cần thiết kế lại monetization theo
  hướng khác, ví dụ quay lại Lifetime IAP như Master Spec gốc).
- Xoá `INTERNET`/`ACCESS_NETWORK_STATE` khỏi Manifest, xoá
  `usesCleartextTraffic`/`network_security_config.xml`.
- Giữ nguyên onboarding claim hiện tại — lúc này mới đúng sự thật.

### Hướng B — Chấp nhận có network SDK, sửa lại claim cho trung thực

- Giữ Sentry + AdMob + INTERNET như hiện tại.
- Sửa `onboarding_screen.dart`: bỏ câu "Không có quyền Internet, không gửi
  dữ liệu ra ngoài thiết bị" — thay bằng mô tả chính xác hơn, ví dụ: *"Dữ
  liệu clipboard/snippet của bạn không bao giờ rời khỏi thiết bị. App dùng
  kết nối mạng chỉ cho quảng cáo (không cá nhân hoá theo nội dung bạn copy)
  và báo lỗi kỹ thuật ẩn danh."*
- Cập nhật Play Console Data Safety form khớp với thực tế (network SDK có
  thu thập device/crash data theo chính sách AdMob/Sentry).
- **Sửa luôn câu claim về password field:** "Smart Clipboard KHÔNG đọc ô
  nhập mật khẩu" — hiện chỉ đúng cho IME custom, không đúng cho việc clipboard
  vẫn có thể lưu password/OTP mà user tự copy. Sửa thành: *"Bàn phím không
  đọc/lưu nội dung ô mật khẩu hệ thống. Nếu bạn copy một mật khẩu vào
  clipboard, hãy dùng Incognito Mode hoặc xoá thủ công sau khi dùng."*

**Không tự chọn hướng nào cho agent** — đây là quyết định cần bạn xác nhận
trước khi patch, vì Hướng A ảnh hưởng ngược lại toàn bộ mục 4 (Pro gate) đã
làm ở trên.

---

## 6. Vietnamese/Telex — giữ nguyên, không động

Xác nhận đã đóng băng đúng như quyết định ở batch 8 (`plan8_final.md`) —
không nằm trong phạm vi remediation này. Không claim hỗ trợ tiếng Việt trên
store cho tới khi có ngân sách kỹ thuật riêng để tích hợp composition engine
đúng cách.

---

## THỨ TỰ THỰC HIỆN

```
1. Restore fix (native, tách biệt, effort thấp, rủi ro thấp)
        ↓
2. Dedup fix (Dart, 1 hàm, effort thấp nhất, rủi ro thấp nhất)
        ↓
3. Release signing (thủ công 1 lần, KHÔNG giao cho agent tạo keystore)
        ↓
[QUYẾT ĐỊNH SẢN PHẨM: chọn Hướng A hoặc B ở mục 5]
        ↓
4. Privacy/Ads (tuỳ hướng đã chọn)
        ↓
5. Pro gate banner (chỉ làm nếu chọn Hướng B; vô nghĩa nếu chọn Hướng A)
```

**Bắt buộc** chọn xong mục 5 trước khi làm mục 4. Không làm mục 4 và 5 tuần
tự mà không quyết định trước — sẽ phải làm lại nếu chọn nhầm hướng.

## TEST TỔNG HỢP TRƯỚC KHI COI LÀ XONG

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Export → Restore đúng file | Thành công, không crash |
| 2 | Copy trùng nội dung 2 lần | `copy_count` tăng đúng, item archived (nếu có) hiện lại |
| 3 | Build `flutter build apk --release` | Ký bằng keystore thật, không phải debug |
| 4 | Verify APK đã ký | `apksigner verify --print-certs app-release.apk` ra đúng cert, không phải Android Debug |
| 5 | Đọc lại toàn bộ onboarding screen | Không còn câu nào mâu thuẫn với Manifest/SDK thực tế |
| 6 | Xem rewarded ad unlock Pro | Banner ads biến mất ngay lập tức |
