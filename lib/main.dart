import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'statistics_page.dart';
import 'data_management_page.dart';
import 'update_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日历 APP',
      theme: ThemeData(
        primaryColor: Color(0xFF4A7CF7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF4A7CF7),
          primary: Color(0xFF4A7CF7),
          secondary: Color(0xFFFF9F43),
        ),
        scaffoldBackgroundColor: Color(0xFFF5F6FA),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF4A7CF7),
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
  final GlobalKey<StatisticsPageState> _statisticsKey = GlobalKey();
  final GlobalKey<DataManagementPageState> _dataKey = GlobalKey();

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
    if (index == 1) {
      _statisticsKey.currentState?.loadEvents();
    } else if (index == 2) {
      _dataKey.currentState?.loadFileInfo();
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
              StatisticsPage(key: _statisticsKey),
              DataManagementPage(key: _dataKey),
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
                    height: 60,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.home_outlined, Icons.home, '首页'),
                            _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart, '统计'),
                            _buildNavItem(2, Icons.backup_outlined, Icons.backup, '数据'),
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
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF4A7CF7) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 22,
              color: isSelected ? Colors.white : Color(0xFF9A9AB0),
            ),
            if (isSelected) ...[
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}