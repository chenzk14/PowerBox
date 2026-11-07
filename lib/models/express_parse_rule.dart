/// 快递短信解析规则。
///
/// 用户可以根据自己收到的短信格式，编写正则来提取取件码、驿站、
/// 地址、手机尾号、快递名。解析时用户自定义规则优先，匹配不到的
/// 字段再落回系统默认规则。
class ExpressParseRule {
  String id;
  String name;
  bool enabled;
  bool isBuiltin;        // 是否系统内置规则（不可删除，可作为模板复制）
  String codePattern;      // 取件码正则
  String stationPattern;   // 驿站正则
  String addressPattern;   // 地址正则
  String phoneTailPattern; // 手机尾号正则
  String courierPattern;   // 快递名正则（可选）
  int priority;            // 优先级，数字越小越优先
  DateTime createdAt;
  DateTime updatedAt;

  ExpressParseRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.isBuiltin = false,
    this.codePattern = '',
    this.stationPattern = '',
    this.addressPattern = '',
    this.phoneTailPattern = '',
    this.courierPattern = '',
    this.priority = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'isBuiltin': isBuiltin,
      'codePattern': codePattern,
      'stationPattern': stationPattern,
      'addressPattern': addressPattern,
      'phoneTailPattern': phoneTailPattern,
      'courierPattern': courierPattern,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ExpressParseRule.fromJson(Map<String, dynamic> json) {
    return ExpressParseRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] ?? true,
      isBuiltin: json['isBuiltin'] ?? false,
      codePattern: json['codePattern']?.toString() ?? '',
      stationPattern: json['stationPattern']?.toString() ?? '',
      addressPattern: json['addressPattern']?.toString() ?? '',
      phoneTailPattern: json['phoneTailPattern']?.toString() ?? '',
      courierPattern: json['courierPattern']?.toString() ?? '',
      priority: json['priority'] is int
          ? json['priority']
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ExpressParseRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    bool? isBuiltin,
    String? codePattern,
    String? stationPattern,
    String? addressPattern,
    String? phoneTailPattern,
    String? courierPattern,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpressParseRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      codePattern: codePattern ?? this.codePattern,
      stationPattern: stationPattern ?? this.stationPattern,
      addressPattern: addressPattern ?? this.addressPattern,
      phoneTailPattern: phoneTailPattern ?? this.phoneTailPattern,
      courierPattern: courierPattern ?? this.courierPattern,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
