import 'dart:math';

/// 快递记录：取件码、驿站、地址等信息
class ExpressEntry {
  String id;

  /// 快递名称/物品名称，例如「顺丰」或「京东-耳机」
  String name;

  /// 取件码
  String code;

  /// 驿站/取件点名称
  String station;

  /// 收货地址
  String address;

  /// 收件手机号后四位
  String phoneTail;

  /// 备注
  String note;

  /// 是否已取件
  bool isPicked;

  DateTime createdAt;
  DateTime updatedAt;

  ExpressEntry({
    String? id,
    this.name = '',
    this.code = '',
    this.station = '',
    this.address = '',
    this.phoneTail = '',
    this.note = '',
    this.isPicked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 列表上显示的标题：名称优先，其次驿站
  String get displayTitle {
    if (name.trim().isNotEmpty) return name.trim();
    if (station.trim().isNotEmpty) return station.trim();
    return '未命名快递';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'station': station,
      'address': address,
      'phoneTail': phoneTail,
      'note': note,
      'isPicked': isPicked,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ExpressEntry.fromJson(Map<String, dynamic> json) {
    return ExpressEntry(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      station: json['station'] ?? '',
      address: json['address'] ?? '',
      phoneTail: json['phoneTail'] ?? '',
      note: json['note'] ?? '',
      isPicked: json['isPicked'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  ExpressEntry copyWith({
    String? name,
    String? code,
    String? station,
    String? address,
    String? phoneTail,
    String? note,
    bool? isPicked,
  }) {
    return ExpressEntry(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      station: station ?? this.station,
      address: address ?? this.address,
      phoneTail: phoneTail ?? this.phoneTail,
      note: note ?? this.note,
      isPicked: isPicked ?? this.isPicked,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
