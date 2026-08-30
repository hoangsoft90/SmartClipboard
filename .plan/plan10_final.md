# Smart Clipboard — Favorite/Pin, Search & Filter, Keyboard Action Center (plan10_final.md)

> Verify trực tiếp trên `clipboard_history_screen.dart`, `snippets_screen.dart`,
> `providers.dart` (`ClipboardListController`, `SnippetListController`) bản
> mới nhất. Tổng hợp từ `plan10.md` + 4 review — mức đồng thuận gần tuyệt đối
> giữa 5 phân tích độc lập, chỉ bổ sung 2 điểm mới: gộp Pin vào Batch 1, và
> kiến trúc filter provider đã verify khả thi trực tiếp trên code thật.

**Thứ tự bắt buộc:** Batch 1 → Batch 2 → Batch 3 → Batch 4. Không gộp, không
làm Batch 4 song song Batch 1-3 — Action Center có phạm vi rộng nhất và đụng
tới native code, tách riêng để tránh regression các phần vừa ổn định.

---

## BATCH 1 (P0) — Favorite + Pin: hiện thực trạng thái đã lưu

### Xác nhận qua code — bug thuần UI, backend đã hoàn chỉnh

```dart
// providers.dart — ClipboardListController, đã đúng và đầy đủ:
Future<void> togglePin(ClipboardItem item) async {
  await _repo.setPinned(item.id, !item.isPinned);
  await reload();
}
Future<void> toggleFavorite(ClipboardItem item) async {
  await _repo.setFavorite(item.id, !item.isFavorite);
  await reload();
}
```

```dart
// clipboard_history_screen.dart — _ItemTile hiện tại:
subtitle: Row(children: [
  Text(_timeAgo(context), ...),
  if (item.copyCount > 1) ...[...],
  if (item.contentType != 'text') ...[...],
  // ❌ Không có gì cho isFavorite / isPinned
]),
trailing: PopupMenuButton<String>(...),  // ❌ chỉ có menu, không có toggle nhanh
```

**Bổ sung quan trọng so với `plan10.md`/4 review:** `isPinned` bị đúng bug y
hệt `isFavorite` (cùng thiếu visual, cùng chỉ toggle được qua PopupMenu) —
sửa cả 2 trong 1 batch, không tách "Pin làm sau" như các tài liệu trước gợi ý
mơ hồ, vì đây là cùng 1 loại lỗi, cùng effort.

### Fix — `clipboard_history_screen.dart`

Tái dùng đúng pattern `trailing: Row(...)` đã có sẵn trong `snippets_screen.dart`
(`_SnippetTile`) để nhất quán style toàn app, thay vì tự nghĩ layout mới:

```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: 20,
        color: item.isPinned ? theme.colorScheme.primary : null,
      ),
      tooltip: item.isPinned ? l10n.popupUnpin : l10n.popupPin,
      onPressed: () =>
          ref.read(clipboardListProvider.notifier).togglePin(item),
    ),
    IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        item.isFavorite ? Icons.star : Icons.star_border,
        size: 20,
        color: item.isFavorite ? Colors.amber : null,
      ),
      tooltip: item.isFavorite ? l10n.popupUnfavorite : l10n.popupFavorite,
      onPressed: () =>
          ref.read(clipboardListProvider.notifier).toggleFavorite(item),
    ),
    PopupMenuButton<String>(
      // giữ nguyên onSelected/itemBuilder hiện có — 'pin'/'favorite' case
      // vẫn hữu ích cho người quen dùng menu, không xoá
      ...
    ),
  ],
),
```

Không cần sửa gì trong `providers.dart` cho batch này — `togglePin()`/
`toggleFavorite()` đã đúng và đủ.

### Test matrix Batch 1

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Bấm icon ⭐ (rỗng) trên 1 item | Icon chuyển vàng ngay, không cần vào menu |
| 2 | Bấm lại | Icon trở về rỗng |
| 3 | Bấm icon 📌 (rỗng) | Icon chuyển đặc/tô màu ngay |
| 4 | Tắt app, mở lại | Trạng thái ⭐/📌 giữ đúng như đã set |
| 5 | Bấm ⭐ qua PopupMenu (cách cũ) | Vẫn hoạt động, đồng bộ với icon mới |

---

## BATCH 2 (P1) — History: Search + Filter

### Kiến trúc — verify khả thi trực tiếp trên `providers.dart` hiện tại

**Không sửa `ClipboardListController`.** State hiện tại là
`StateNotifier<AsyncValue<List<ClipboardItem>>>` thuần — thêm filter vào đây
sẽ buộc đổi kiểu state và phải sửa lại mọi hàm `reload/togglePin/
toggleFavorite/archiveItem/deleteForever` để không làm mất filter mỗi lần set
`state = ...`. Thay vào đó, **tách filter thành 1 provider hoàn toàn độc lập**
+ 1 provider phái sinh tính `visibleItems` — cách này không đụng một dòng nào
trong `ClipboardListController`, loại bỏ hoàn toàn rủi ro filter bị reset khi
favorite/pin/archive.

**File mới hoặc thêm vào cuối `providers.dart`:**

```dart
// --------------------------- Clipboard Filter (Batch 2) ---------------------------

class ClipboardFilterState {
  final String query;
  final bool favoriteOnly;
  final bool pinnedOnly;

  const ClipboardFilterState({
    this.query = '',
    this.favoriteOnly = false,
    this.pinnedOnly = false,
  });

  ClipboardFilterState copyWith({
    String? query,
    bool? favoriteOnly,
    bool? pinnedOnly,
  }) =>
      ClipboardFilterState(
        query: query ?? this.query,
        favoriteOnly: favoriteOnly ?? this.favoriteOnly,
        pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      );
}

final clipboardFilterProvider =
    StateProvider<ClipboardFilterState>((ref) => const ClipboardFilterState());

/// Provider phái sinh — KHÔNG đụng ClipboardListController.
/// Tự động re-tính mỗi khi list gốc HOẶC filter đổi.
final visibleClipboardItemsProvider = Provider<List<ClipboardItem>>((ref) {
  final items = ref.watch(clipboardListProvider).value ?? const <ClipboardItem>[];
  final f = ref.watch(clipboardFilterProvider);

  return items.where((item) {
    if (f.favoriteOnly && !item.isFavorite) return false;
    if (f.pinnedOnly && !item.isPinned) return false;
    if (f.query.isNotEmpty &&
        !item.content.toLowerCase().contains(f.query.toLowerCase())) {
      return false;
    }
    return true;
  }).toList();
});
```

### UI — `clipboard_history_screen.dart`

```dart
final listAsync = ref.watch(clipboardListProvider);   // giữ nguyên — loading/error
final visibleItems = ref.watch(visibleClipboardItemsProvider);   // ✅ thêm mới
final filter = ref.watch(clipboardFilterProvider);
```

Thay `items` trong `listAsync.when(data: (items) => ...)` bằng `visibleItems`
để render (giữ `listAsync.when` chỉ cho trạng thái loading/error, không dùng
`items` trực tiếp từ đó nữa cho phần hiển thị).

Thêm search bar + filter chips ngay dưới `AppBar` (trên `ProUpgradeBanner`):

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: TextField(
    decoration: InputDecoration(
      hintText: l10n.searchClipboardHint,
      prefixIcon: const Icon(Icons.search),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onChanged: (value) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        ref.read(clipboardFilterProvider.notifier).state =
            filter.copyWith(query: value);
      });
    },
  ),
),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: Wrap(spacing: 8, children: [
    ChoiceChip(
      label: Text(l10n.filterAll),
      selected: !filter.favoriteOnly && !filter.pinnedOnly,
      onSelected: (_) => ref.read(clipboardFilterProvider.notifier).state =
          filter.copyWith(favoriteOnly: false, pinnedOnly: false),
    ),
    ChoiceChip(
      label: Text(l10n.filterFavorites),
      selected: filter.favoriteOnly,
      onSelected: (v) => ref.read(clipboardFilterProvider.notifier).state =
          filter.copyWith(favoriteOnly: v),
    ),
    ChoiceChip(
      label: Text(l10n.filterPinned),
      selected: filter.pinnedOnly,
      onSelected: (v) => ref.read(clipboardFilterProvider.notifier).state =
          filter.copyWith(pinnedOnly: v),
    ),
  ]),
),
```

`_ItemTile` cần biến `ConsumerWidget` thành `ConsumerStatefulWidget` (cho
`_debounce`), hoặc đặt `TextField`+`Timer` ở widget riêng `_SearchBar` để
tránh rebuild toàn bộ list mỗi khi gõ — khuyến nghị dùng cách 2 (tách widget
riêng), rebuild ít hơn.

**Không thêm content-type filter (URL/Email/Phone/Sensitive) trong batch
này** — đúng theo phản biện của review3: giữ scope hẹp (query + favorite +
pinned), filter chi tiết hơn để P1.5 riêng nếu thực sự cần, tránh phình UI
ngay từ đầu.

### Test matrix Batch 2

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Gõ từ khoá vào search | Sau ~300ms, list lọc đúng theo nội dung chứa từ khoá |
| 2 | Gõ nhanh liên tục | Không giật UI, chỉ filter 1 lần sau khi ngừng gõ |
| 3 | Xoá hết search | Hiện lại toàn bộ |
| 4 | Bấm chip "⭐ Favorites" | Chỉ hiện item favorite |
| 5 | Kết hợp search + chip Favorites | Chỉ hiện item vừa match search vừa favorite |
| 6 | Đang filter Favorites, bấm unfavorite 1 item | Item biến mất khỏi list ngay, filter không bị reset |
| 7 | Đang có search "meeting", bấm pin 1 item khác | Search vẫn giữ nguyên, không bị xoá |

---

## BATCH 3 (P1) — Snippet: Search + Filter

Áp dụng **y hệt kiến trúc Batch 2**, không tạo pattern khác:

```dart
class SnippetFilterState {
  final String query;
  final bool enabledOnly;
  final String? folderId;

  const SnippetFilterState({this.query = '', this.enabledOnly = false, this.folderId});

  SnippetFilterState copyWith({String? query, bool? enabledOnly, String? Function()? folderId}) =>
      SnippetFilterState(
        query: query ?? this.query,
        enabledOnly: enabledOnly ?? this.enabledOnly,
        folderId: folderId != null ? folderId() : this.folderId,
      );
}

final snippetFilterProvider =
    StateProvider<SnippetFilterState>((ref) => const SnippetFilterState());

final visibleSnippetsProvider = Provider<List<Snippet>>((ref) {
  final items = ref.watch(snippetListProvider).value ?? const <Snippet>[];
  final f = ref.watch(snippetFilterProvider);

  return items.where((s) {
    if (f.enabledOnly && !s.isEnabled) return false;
    if (f.folderId != null && s.folderId != f.folderId) return false;
    if (f.query.isNotEmpty) {
      final q = f.query.toLowerCase();
      final match = s.title.toLowerCase().contains(q) ||
          s.trigger.toLowerCase().contains(q) ||
          s.content.toLowerCase().contains(q);
      if (!match) return false;
    }
    return true;
  }).toList();
});
```

UI `snippets_screen.dart`: thêm search bar + chips "All / ✅ Enabled / ⛔
Disabled" theo đúng pattern Batch 2. Folder filter dùng dropdown đơn giản đọc
từ `folderListProvider` đã có sẵn — không cần thêm gì mới ở tầng repository.

### Test matrix Batch 3

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Gõ từ khoá match `title`/`trigger`/`content` | Lọc đúng, không phân biệt hoa/thường |
| 2 | Bấm chip "Enabled" | Chỉ hiện snippet `isEnabled == true` |
| 3 | Chọn 1 folder | Chỉ hiện snippet trong folder đó |
| 4 | Kết hợp search + Enabled + Folder | Áp dụng đúng cả 3 điều kiện cùng lúc |
| 5 | Đang filter, toggle enabled 1 snippet | List cập nhật đúng, filter không mất |

---

## BATCH 4 (P2) — Keyboard Action Center

> Chỉ bắt đầu sau khi Batch 1-3 đã merge và ổn định. Đụng native code
> (`SmartClipboardIME.kt`) — tách riêng để không lẫn với thay đổi Flutter
> thuần ở 3 batch trên.

### Thiết kế — đồng thuận cả `plan10.md` + 4 review, không nhồi toolbar

```
QuickToolbar:  ;  @  .com   |   😀   📋   ⋯
                              tap ↓
                Tray: Emoji | Clipboard (Recent + ⭐ Favorites)
```

Giữ đúng nguyên tắc đã chốt xuyên suốt dự án: **IME không query SQLite trực
tiếp**, chỉ đọc cache file JSON, giống hệt pattern `snippets_cache.json` đã
verify hoạt động ổn định qua nhiều batch trước.

### Cache — `clipboard_cache.json`

```json
{
  "version": 1,
  "recent": [ { "id": "...", "content": "...", "content_type": "text" }, ... ],
  "favorites": [ { "id": "...", "content": "...", "content_type": "text" }, ... ]
}
```

- Giới hạn **tối đa 30 item mỗi danh sách** (recent, favorites) — đủ dùng
  trong 1 tray cuộn, tránh file phình to.
- Ghi file: Flutter gọi lại đúng `CacheSyncService` đã có sẵn (dùng chung
  cơ chế atomic write `.tmp` → rename + `cache_version` monotonic counter đã
  verify đúng ở các batch trước cho snippet cache) — **không** tạo cơ chế
  IPC mới, tái dùng service hiện có.
- Trigger regenerate: sau mỗi `toggleFavorite()`, `captureFromSystem()`
  (item mới), `archiveItem()`, `deleteForever()`.
- IME đọc file **1 lần lúc `onStartInputView()`** vào RAM — không đọc lại
  mỗi lần mở tray, không poll liên tục.

### Native — `SmartClipboardIME.kt`

Thêm nút `📋` vào `QuickToolbar` (theo đúng pattern nút 🌐/😀 đã có), mở
`ClipboardTray` (tương tự `EmojiTray` đã có kiến trúc sẵn — Grid/List đơn
giản, tap → `ic.commitText(content, 1)`).

**Tách file theo đúng đề xuất của `plan10.md`** (không bắt buộc trong 1
lần, nhưng nên làm khi đụng tới phần này vì `SmartClipboardIME.kt` đã khá
lớn sau nhiều batch):
```
android/.../keyboard/
    QuickToolbar.kt      (tách khỏi SmartClipboardIME.kt)
    EmojiTray.kt          (tách)
    ClipboardTray.kt      (mới)
    ClipboardCache.kt     (parse JSON, model Recent/Favorites)
```

### Test matrix Batch 4

| # | Bước | Kỳ vọng |
|---|---|---|
| 1 | Favorite 1 item trong app, mở keyboard, tap 📋 | Item xuất hiện trong tab Favorites của tray |
| 2 | Tap 1 item trong tray | Nội dung được chèn đúng vào ô input đang gõ |
| 3 | Unfavorite item đó trong app, đóng mở lại keyboard | Item không còn trong tray (đọc cache mới ở session sau) |
| 4 | Tạo > 30 item mới | Cache chỉ giữ 30 item gần nhất, không phình file |
| 5 | Mở tray nhiều lần liên tục trong cùng session | Không có độ trễ/giật, không đọc lại file mỗi lần mở |

---

## KHÔNG LÀM TRONG 4 BATCH NÀY

- Không thêm content-type filter (URL/Email/Phone/Sensitive) — để riêng nếu
  có nhu cầu thực tế sau khi có dữ liệu sử dụng.
- Không thêm sort options (Newest/Most used/Alphabetical) — mặc định giữ
  nguyên thứ tự hiện có của `getActive()`/`getAll()`.
- Không dùng SQLite FTS5 — dataset hiện tại (giới hạn Free tier) đủ nhỏ để
  filter trên RAM.
- Không dùng `ContentProvider` cho Batch 4 — file JSON cache giới hạn size +
  đọc 1 lần/session là đủ cho MVP, nhất quán với cách đã làm cho snippet.
- Không làm Batch 4 chung PR với Batch 1-3.