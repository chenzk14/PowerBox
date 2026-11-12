import 'package:flutter/services.dart';

/// 透明悬浮窗保活（com.powerbox.app/keepalive）。
///
/// 原生侧在 BatteryMonitorService 里挂一个 1x1、alpha=0.01、不可触摸的
/// TYPE_APPLICATION_OVERLAY 窗口，用来降低进程被系统回收的优先级。
///
/// 注意：
/// - 悬浮窗只能降低被杀概率，进程已经被杀时它无法复活；
/// - 需要用户手动授予「显示悬浮窗」特殊权限（SYSTEM_ALERT_WINDOW）；
/// - 部分 ROM 会提示「正在其他应用上显示」，这是系统行为。
class KeepAliveService {
  static const MethodChannel _channel =
      MethodChannel('com.powerbox.app/keepalive');

  /// 是否已开启透明悬浮窗保活（只读偏好，不代表权限一定还在）
  static Future<bool> isFloatingKeepAlive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFloatingKeepAlive');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 是否已授予「显示悬浮窗」权限
  static Future<bool> isOverlayPermissionGranted() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isOverlayPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 跳转系统授权页；返回 true 只表示页面已打开
  static Future<bool> requestOverlayPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 设置是否开启透明悬浮窗保活。
  ///
  /// 返回 false 表示没有悬浮窗权限或原生设置失败，调用方应保持开关关闭。
  static Future<bool> setFloatingKeepAlive(bool value) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setFloatingKeepAlive',
        {'value': value},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
