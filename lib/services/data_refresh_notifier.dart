import 'package:flutter/foundation.dart';

/// 数据变更通知：导入等操作完成后，通知常驻页面重新加载数据。
/// 首页和密码管理页放在 IndexedStack 中，initState 只执行一次，
/// 所以需要通过这个通知让它们主动刷新，避免必须重启应用才能看到导入结果。
final ValueNotifier<int> dataRefreshNotifier = ValueNotifier<int>(0);

/// 通知所有监听页面数据已变更
void notifyDataChanged() {
  dataRefreshNotifier.value++;
}
