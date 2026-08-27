/// Model bảng `clipboard_items` — Master Spec mục 2.
class ClipboardItem {
  final String id;
  final String content;
  final String contentHash; // SHA256(normalize(content)) — dedup
  final String contentType; // 'text','url','email','phone','sensitive'
  final int createdAt;
  final int updatedAt;
  final int? lastUsedAt;
  final int copyCount;
  final bool isPinned;
  final bool isFavorite;

  /// ⚠️ HEURISTIC ONLY (mục 5.1): 0 an toàn / 1 nghi vấn / 2 rủi ro cao.
  /// Không phải security guarantee.
  final int privacyRiskScore;
  final bool isArchived;

  /// Metadata thông tin, không phải security boundary.
  final String? sourceApp;
  final int? expiresAt;

  const ClipboardItem({
    required this.id,
    required this.content,
    required this.contentHash,
    this.contentType = 'text',
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.copyCount = 1,
    this.isPinned = false,
    this.isFavorite = false,
    this.privacyRiskScore = 0,
    this.isArchived = false,
    this.sourceApp,
    this.expiresAt,
  });

  factory ClipboardItem.fromMap(Map<String, Object?> map) => ClipboardItem(
        id: map['id'] as String,
        content: map['content'] as String,
        contentHash: map['content_hash'] as String,
        contentType: (map['content_type'] as String?) ?? 'text',
        createdAt: map['created_at'] as int,
        updatedAt: map['updated_at'] as int,
        lastUsedAt: map['last_used_at'] as int?,
        copyCount: (map['copy_count'] as int?) ?? 1,
        isPinned: ((map['is_pinned'] as int?) ?? 0) == 1,
        isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
        privacyRiskScore: (map['privacy_risk_score'] as int?) ?? 0,
        isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
        sourceApp: map['source_app'] as String?,
        expiresAt: map['expires_at'] as int?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'content': content,
        'content_hash': contentHash,
        'content_type': contentType,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'last_used_at': lastUsedAt,
        'copy_count': copyCount,
        'is_pinned': isPinned ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
        'privacy_risk_score': privacyRiskScore,
        'is_archived': isArchived ? 1 : 0,
        'source_app': sourceApp,
        'expires_at': expiresAt,
      };
}
