import 'package:flutter/material.dart';
import '../pages/data_management_page.dart';

/// 全局顶部栏：左侧 App 图标 + 名称 + 副标题，右侧圆形设置按钮。
///
/// 标题与副标题固定，不随页面变化。
/// [onSettingsTap] 不传时默认打开数据管理页；传入回调可自定义跳转行为。
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.onSettingsTap,
  });

  final VoidCallback? onSettingsTap;

  void _handleSettingsTap(BuildContext context) {
    if (onSettingsTap != null) {
      onSettingsTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DataManagementPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // App 图标：与 Android 端 ic_launcher 同一张图，裁圆角避免生硬的方块
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10),
          // 标题 + 副标题：整体高度固定 40，与右侧设置按钮等高
          SizedBox(
            height: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PowerBox',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                    letterSpacing: 0.5,
                  ),
                ),
                // 固定副标题：不随页面变化
                Text(
                  '打卡 · 统计 · 密码管理',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Spacer(),
          // 设置按钮：直径与左侧标题区域高度一致（40）
          GestureDetector(
            onTap: () => _handleSettingsTap(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFFE1E1E1)),
              ),
              child: Icon(
                Icons.settings,
                size: 24,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
