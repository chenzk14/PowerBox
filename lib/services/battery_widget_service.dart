import 'package:flutter/services.dart';

/// 电池信息 MethodChannel 封装（com.powerbox.app/battery）。
///
/// 原生侧实现见 MainActivity.kt，可用于：
/// - 读取实时电池数据（校准页展示对照）
/// - 保存校准值后触发桌面小组件刷新
class BatteryWidgetService {
  static const MethodChannel _channel = MethodChannel('com.powerbox.app/battery');

  /// 读取实时电池数据，读取失败返回 null。
  ///
  /// 返回 Map：chargeCounterMah(double?)、temperatureC(double?)、
  /// voltageMv(int?)、currentMa(double?，充电时为正值)、isCharging(bool)
  static Future<Map<String, dynamic>?> getBatteryInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getBatteryInfo');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 让桌面小组件刷新一次
  static Future<bool> refreshWidget() async {
    try {
      final result = await _channel.invokeMethod<bool>('refreshWidget');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
