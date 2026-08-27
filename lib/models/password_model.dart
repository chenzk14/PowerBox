import 'dart:math';

class PasswordEntry {
  String id;
  String name;
  String account;
  String password;
  DateTime createdAt;
  DateTime updatedAt;

  PasswordEntry({
    String? id,
    required this.name,
    required this.account,
    required this.password,
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
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  PasswordEntry copyWith({
    String? name,
    String? account,
    String? password,
  }) {
    return PasswordEntry(
      id: id,
      name: name ?? this.name,
      account: account ?? this.account,
      password: password ?? this.password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}