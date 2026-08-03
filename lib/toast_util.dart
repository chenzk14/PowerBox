import 'package:flutter/material.dart';

OverlayEntry? _currentEntry;

void showToast(BuildContext context, String message) {
  // 移除上一个toast，避免重叠
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A2E).withValues(alpha: 0.85),
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
      ),
    ),
  );

  _currentEntry = entry;
  overlay.insert(entry);
  Future.delayed(Duration(milliseconds: 1500), () {
    entry.remove();
    if (_currentEntry == entry) {
      _currentEntry = null;
    }
  });
}