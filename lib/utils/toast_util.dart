import 'package:flutter/material.dart';

OverlayEntry? _currentEntry;

/// 轻提示。
///
/// [atBottom] 为 true 时显示在屏幕底部，否则保持居中；
/// [duration] 默认 1.5 秒，导入/导出等需要看清的内容可以传 3 秒。
void showToast(
  BuildContext context,
  String message, {
  bool atBottom = false,
  Duration duration = const Duration(milliseconds: 1500),
}) {
  // 移除上一个toast，避免重叠
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final content = Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFF333333).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      );

      if (atBottom) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 80,
          child: Center(child: content),
        );
      }
      return Center(child: content);
    },
  );

  _currentEntry = entry;
  overlay.insert(entry);
  Future.delayed(duration, () {
    // 期间若又弹出了新的 toast，旧的 entry 已被 showToast 移除，
    // 再次 remove 会触发 “An OverlayEntry should be removed only once” 断言
    if (entry.mounted) {
      entry.remove();
    }
    if (_currentEntry == entry) {
      _currentEntry = null;
    }
  });
}
