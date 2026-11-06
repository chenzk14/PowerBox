import 'dart:ui';
import 'package:flutter/material.dart';
import 'pages/express_page.dart';
import 'pages/home_page.dart';
import 'pages/password_manager_page.dart';
import 'services/battery_widget_service.dart';
import 'services/shortcut_service.dart';
import 'services/update_service.dart';

/// 全局导航 key：桌面快捷方式跳转时使用，避免拿不到 context
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ShortcutService.init();
  ShortcutService.actionStream.listen(_handleShortcutAction);
  runApp(MyApp());

  // 冷启动：首帧之后主动拉取原生缓存的快捷方式动作
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final action = await ShortcutService.getInitialAction();
    if (action != null) {
      _handleShortcutAction(action);
    }
  });

  // 冷启动时顺便刷新一次桌面电池小组件
  BatteryWidgetService.refreshWidget();
}

/// 处理桌面快捷方式跳转
DateTime? _lastShortcutHandledAt;

void _handleShortcutAction(String action, {int attempt = 0}) {
  if (action != ShortcutService.actionExpress) return;

  // 已经停留在快递页时不重复打开
  if (ExpressPage.isVisible) return;

  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    // 首帧尚未构建完成，下一帧再试
    if (attempt < 20) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleShortcutAction(action, attempt: attempt + 1),
      );
    }
    return;
  }

  // 冷启动与热启动两条通路可能同时到达，做一个短间隔防抖
  final now = DateTime.now();
  if (_lastShortcutHandledAt != null &&
      now.difference(_lastShortcutHandledAt!).inMilliseconds < 1500) {
    return;
  }
  _lastShortcutHandledAt = now;

  navigator.push(
    MaterialPageRoute(builder: (context) => const ExpressPage()),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PowerBox',
      theme: ThemeData(
        primaryColor: Color(0xFF333333),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF333333),
          primary: Color(0xFF333333),
          secondary: Color(0xFF666666),
        ),
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF333333),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final GlobalKey<PasswordManagerPageState> _passwordKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 启动时自动检查更新
    _checkUpdateOnStartup();
  }

  /// 启动时检查更新
  void _checkUpdateOnStartup() async {
    // 延迟2秒后检查，避免影响启动速度
    await Future.delayed(Duration(seconds: 2));
    
    if (!mounted) return;
    
    final updateInfo = await UpdateService.checkForUpdate();
    
    if (updateInfo != null && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    }
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    // 切换到密码管理时才请求身份验证，避免启动即弹指纹
    if (index == 1) {
      _passwordKey.currentState?.unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              HomePage(),
              PasswordManagerPage(
                key: _passwordKey,
                autoAuthenticate: false,
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    // 标准底部导航高度：图标在上、文字在下常驻显示
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      // 白色底栏用顶部细边框代替阴影
                      border: Border(
                        top: BorderSide(color: Color(0xFFE1E1E1), width: 1),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.calendar_month_outlined, Icons.calendar_month, '打卡管理'),
                            _buildNavItem(1, Icons.lock_outline, Icons.lock, '密码管理'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    // 未选中为灰色，选中为黑色；图标与文字常驻
    final color = isSelected ? Color(0xFF333333) : Color(0xFF999999);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabChanged(index),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 20,
              color: color,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}