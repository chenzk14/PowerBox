import 'dart:math';

class PasswordEntry {
  String id;
  String name;
  String account;
  String password;
  DateTime createdAt;
  DateTime updatedAt;

  /// 卡片图标标识。
  /// null 表示按名称自动匹配；空字符串表示强制使用首字母头像；
  /// 其他值对应 app_icon_catalog.dart 中的图标 key。
  String? iconKey;

  PasswordEntry({
    String? id,
    required this.name,
    required this.account,
    required this.password,
    this.iconKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get avatarText {
    if (name.isEmpty) return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final firstChar = trimmed[0];
    return firstChar.toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account': account,
      'password': password,
      'iconKey': iconKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      id: json['id'],
      name: json['name'],
      account: json['account'],
      password: json['password'],
      iconKey: json['iconKey'] as String?,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  PasswordEntry copyWith({
    String? name,
    String? account,
    String? password,
    String? iconKey,
  }) {
    return PasswordEntry(
      id: id,
      name: name ?? this.name,
      account: account ?? this.account,
      password: password ?? this.password,
      iconKey: iconKey ?? this.iconKey,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}