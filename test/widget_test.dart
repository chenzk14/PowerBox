// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com.powerbox.app/main.dart';

void main() {
  testWidgets('PowerBox 可以正常构建', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 启动检查更新有 2 秒延迟，推进时间避免测试结束时留下 pending timer。
    await tester.pump(const Duration(seconds: 3));

    // 只要能构建出 MaterialApp，就说明根组件没有在启动阶段抛异常。
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
