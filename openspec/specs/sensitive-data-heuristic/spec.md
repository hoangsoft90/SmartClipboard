# Sensitive Data Heuristic Specification

## Purpose

GỢI Ý cho user rằng văn bản có thể chứa dữ liệu nhạy cảm, để user tự quyết định có lưu hay không. Output là `privacy_risk_score` (0/1/2) — KHÔNG PHẢI security guarantee, KHÔNG gắn nhãn cứng "đây là mật khẩu". Mọi điểm chạm UI/comment phải mang tính "heuristic/dự đoán".

## Requirements

### Requirement: Scoring 3 mức

`PrivacyService.assess(content)` (file: `lib/services/privacy_service.dart`) PHẢI trả về theo thứ tự ưu tiên:
1. **Score 2** nếu khớp bất kỳ regex nào trong `SensitivePatterns.all`: OTP 6 số đứng độc lập, số thẻ 13–19 chữ số (có thể phân nhóm space/-), API key (`sk-`, `AKIA`, `ghp_`, `github_pat_`, `xox*-`), seed phrase ≥12 từ, khối PEM private key. content_type = 'sensitive'.
2. **Score 1** nếu: độ dài ≥16, Shannon entropy ≥ 3.5 bits/char, và số lớp ký tự ≥ 3 (thường/HOA/số/ký hiệu ASCII). content_type = 'sensitive'.
3. **Score 0**: phân loại content_type — 'url' (`^https?://\S+$`), 'email', 'phone', còn lại 'text'.

#### Scenario: OTP
- **GIVEN** nội dung "Mã OTP của bạn là 483920"
- **WHEN** assess
- **THEN** riskScore = 2 do pattern OTP.

#### Scenario: Chuỗi random entropy cao
- **GIVEN** chuỗi 28 ký tự trộn 4 lớp ký tự
- **WHEN** assess
- **THEN** riskScore = 1 (nghi vấn, KHÔNG chắc chắn).

#### Scenario: Text tiếng Việt thường
- **GIVEN** "Họp lúc 3 giờ chiều tại văn phòng nhé" (chỉ 2 lớp ký tự)
- **WHEN** assess
- **THEN** riskScore = 0 dù entropy có thể vượt ngưỡng (gate classes ≥ 3 chặn false positive).

### Requirement: Disclaimer heuristic ở mọi điểm chạm

Badge rủi ro trên history item (file: `lib/widgets/privacy_banner.dart`) dùng Tooltip với từ "Heuristic... Chỉ là dự đoán". Settings có dòng giải thích "CHỈ LÀ heuristic... KHÔNG PHẢI bảo đảm bảo mật tuyệt đối". Dialog chặn capture cũng có disclaimer tương tự.

#### Scenario: Badge item score 2
- **GIVEN** item risk score 2
- **WHEN** render tile trong history
- **THEN** leading hiển thị badge errorContainer; long-press tooltip nêu rõ đây là dự đoán heuristic.

### Requirement: Hạn chế thời gian lưu khi nghi vấn

Khi user đồng ý banner "Tự động xoá sau 24h?" (qua dialog capture hoặc menu item), hệ thống set `expires_at = now + 24h` (hằng số `AppLimits.sensitiveAutoDeleteHours`). Score = 2 KHÔNG BAO GIỜ được lưu tự động nếu user không xác nhận.

#### Scenario: User từ chối lưu OTP
- **GIVEN** capture bị block vì OTP
- **WHEN** user bấm "Không lưu"
- **THEN** không có row nào được INSERT vào clipboard_items.

## Cần làm rõ

- Regex thẻ ngân hàng chỉ check độ dài 13–19 chữ số, chưa có kiểm tra Luhn → dải số điện thoại dài/nhóm số có thể false positive score 2. Có cần thêm Luhn để giảm nhiễu không?
- Pattern seed phrase yêu cầu toàn bộ từ lowercase ASCII `[a-z]{3,}` — seed phrase chứa từ < 3 ký tự (vd BIP39 "add", "egg"... thực ra ≥3 nhưng một số wordlist khác) hoặc viết hoa đầu câu sẽ miss. Đây là giới hạn đã chấp nhận hay cần nới?
