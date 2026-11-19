import 'package:flutter/material.dart';

/// 二级页面统一的左上角返回按钮。
///
/// 仅保留图标，不显示背景色和边框；[onTap] 不传时默认执行
/// [Navigator.maybePop]。
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Color(0xFF333333),
        ),
      ),
    );
  }
}
