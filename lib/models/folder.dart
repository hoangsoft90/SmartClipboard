/// Model bảng `folders` — Master Spec mục 2.
class Folder {
  final String id;
  final String name;
  final String? icon;
  final int createdAt;

  const Folder({
    required this.id,
    required this.name,
    this.icon,
    required this.createdAt,
  });

  factory Folder.fromMap(Map<String, Object?> map) => Folder(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        createdAt: map['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'created_at': createdAt,
      };
}
