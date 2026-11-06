import 'dart:async';
import 'package:flutter/services.dart';

/// 接收 Android 桌面快捷方式（长按图标）的跳转事件
///
/// 冷启动时事件会早于 Flutter 初始化，因此原生侧会先缓存，
/// Dart 侧初始化完成后通过 [getInitialAction] 主动拉取一次。
class ShortcutService {
  static const MethodChannel _channel = MethodChannel('com.powerbox.app/shortcut');

  /// 快捷方式动作名：进入快递管理
  static const String actionExpress = 'express';

  static final StreamController<String> _actionController =
      StreamController<String>.broadcast();

  static bool _initialized = false;
  static String? _lastAction;
  static DateTime? _lastActionAt;

  /// 快捷方式动作流（热启动时由原生侧推送）
  static Stream<String> get actionStream => _actionController.stream;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShortcut') {
        final action = call.arguments as String?;
        if (action != null && action.isNotEmpty) {
          _emit(action);
        }
      }
      return null;
    });
  }

  /// 拉取冷启动时缓存的快捷方式动作，读取后原生侧会清空
  static Future<String?> getInitialAction() async {
    try {
      return await _channel.invokeMethod<String>('getInitialShortcut');
    } on PlatformException catch (e) {
      print('读取快捷方式失败: $e');
      return null;
    } on MissingPluginException {
      // 非 Android 平台或未实现，忽略
      return null;
    }
  }

  /// 防止冷启动与热启动两条通路短时间内重复跳转
  static void _emit(String action) {
    final now = DateTime.now();
    if (_lastAction == action &&
        _lastActionAt != null &&
        now.difference(_lastActionAt!).inMilliseconds < 1500) {
      return;
    }
    _lastAction = action;
    _lastActionAt = now;
    if (!_actionController.isClosed) {
      _actionController.add(action);
    }
  }
}
