import 'package:shared_preferences/shared_preferences.dart';

/// 电池校准数据（设计容量 / 最大容量）。
///
/// HyperOS 隐藏了健康度百分比，系统也不向第三方应用开放
/// charge_full / charge_full_design，因此这里让用户手动校准：
/// 默认值都是小米 14 标称的 4610mAh。
///
/// 注意：SharedPreferences 里的值以 String 存储，
/// 原生小组件侧用同样的 key（前缀 flutter.）读取。
class BatterySettings {
  static const String _designCapacityKey = 'battery_design_capacity';
  static const String _maxCapacityKey = 'battery_max_capacity';

  /// 小米 14 标称设计容量（mAh）
  static const int defaultDesignCapacity = 4610;

  /// 小米 14 标称最大容量（mAh），未校准前按设计容量算
  static const int defaultMaxCapacity = 4610;

  static Future<int> getDesignCapacity() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseCapacity(prefs.getString(_designCapacityKey)) ??
        defaultDesignCapacity;
  }

  static Future<int> getMaxCapacity() async {
    final prefs = await SharedPreferences.getInstance();
    // 未校准时返回设计容量，保证最大容量比为 100%
    return _parseCapacity(prefs.getString(_maxCapacityKey)) ??
        await getDesignCapacity();
  }

  static Future<void> setDesignCapacity(int mah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_designCapacityKey, mah.toString());
  }

  static Future<void> setMaxCapacity(int mah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_maxCapacityKey, mah.toString());
  }

  static int? _parseCapacity(String? raw) {
    if (raw == null) return null;
    final value = int.tryParse(raw);
    // 容量合理范围：500 ~ 10000 mAh
    if (value == null || value < 500 || value > 10000) return null;
    return value;
  }
}
