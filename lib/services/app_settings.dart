import 'package:shared_preferences/shared_preferences.dart';

/// App 级设置项
class AppSettings {
  static const String _expressAuthKey = 'express_auth_enabled';

  /// 进入快递页是否需要验证身份，默认开启
  static Future<bool> getExpressAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expressAuthKey) ?? true;
  }

  static Future<void> setExpressAuthEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expressAuthKey, value);
  }
}
