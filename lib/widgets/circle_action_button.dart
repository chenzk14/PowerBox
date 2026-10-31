import 'package:flutter/material.dart';

/// 圆形操作按钮。
/// 背景色与首页「统计详情」按钮一致（#333333 实心），
/// 用于首页「一键打卡」与密码管理页的「新增」按钮。
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.iconSize = 28,
  });

  final VoidCallback onTap;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 与「统计详情」按钮一致的实心背景色
          color: Color(0xFF333333),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
