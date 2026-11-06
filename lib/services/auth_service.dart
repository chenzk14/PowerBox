import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// 身份验证：优先使用生物识别，失败时回退到设备密码
class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// 返回 true 表示验证通过。
  /// 设备未设置生物识别或锁屏密码时直接放行，避免把用户挡在门外。
  static Future<bool> authenticate({String reason = '请验证身份'}) async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      final hasBiometrics = availableBiometrics.isNotEmpty;
      final hasDeviceCredentials = await _localAuth.isDeviceSupported();

      if (!hasBiometrics && !hasDeviceCredentials) {
        print('设备未设置生物识别或锁屏密码，跳过认证');
        return true;
      }

      if (!canCheckBiometrics && !isDeviceSupported) {
        return true;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      print('认证错误: $e');
      if (e.code == 'no_fragment_activity') {
        print('Activity不是FragmentActivity，跳过认证');
        return true;
      }
      return false;
    }
  }
}
