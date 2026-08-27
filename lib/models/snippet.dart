/// Model bảng `snippets` — Master Spec mục 2.
class Snippet {
  final String id;
  final String title;
  final String trigger; // vd: ;email (không tính prefix)
  final String content;
  final String prefix; // tiền tố, mặc định ';' (Pro: cho phép đổi)
  final String? folderId;
  final bool isEnabled;
  final bool isArchived; // soft-delete khi vượt Free limit — STRICT RULE 17
  final int usageCount;
  final int createdAt;
  final int updatedAt;

  const Snippet({
    required this.id,
    required this.title,
    required this.trigger,
    required this.content,
    this.prefix = ';',
    this.folderId,
    this.isEnabled = true,
    this.isArchived = false,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Snippet.fromMap(Map<String, Object?> map) => Snippet(
        id: map['id'] as String,
        title: map['title'] as String,
        trigger: map['trigger'] as String,
        content: map['content'] as String,
        prefix: (map['prefix'] as String?) ?? ';',
        folderId: map['folder_id'] as String?,
        isEnabled: ((map['is_enabled'] as int?) ?? 1) == 1,
        isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
        usageCount: (map['usage_count'] as int?) ?? 0,
        createdAt: map['created_at'] as int,
        updatedAt: map['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'trigger': trigger,
        'content': content,
        'prefix': prefix,
        'folder_id': folderId,
        'is_enabled': isEnabled ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'usage_count': usageCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Token đầy đủ hiển thị trên UI: `;email`.
  String get fullTrigger => '$prefix$trigger';
}
