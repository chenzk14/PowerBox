import 'package:flutter/services.dart';

/// 最近任务卡片控制（com.powerbox.app/task）。
///
/// 用途：把 PowerBox 从「最近任务」列表中隐藏，避免卡片被误滑清理。
/// 注意：
/// - 「锁定后台」需要用户自己在最近任务里手动下拉锁定，应用无法代劳；
/// - 隐藏卡片不会阻止 HyperOS 的省电策略杀进程，只是防误滑；
/// - 隐藏后最近任务里看不到 PowerBox，需要从桌面图标进入本页关闭开关。
class TaskService {
  static const MethodChannel _channel = MethodChannel('com.powerbox.app/task');

  /// 是否已在最近任务中隐藏，读取失败时按「未隐藏」处理。
  static Future<bool> isHideFromRecents() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHideFromRecents');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 设置是否在最近任务中隐藏。
  ///
  /// 返回 true 表示原生侧已成功应用到当前任务；false 表示系统未接受
  /// （例如当前还没有可操作的任务）。
  static Future<bool> setHideFromRecents(bool value) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setHideFromRecents',
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
