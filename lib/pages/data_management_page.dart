import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_model.dart';
import '../services/file_storage.dart';
import '../services/local_storage.dart';
import '../utils/toast_util.dart';
import '../services/update_service.dart';
import '../services/password_storage.dart';
import '../services/data_refresh_notifier.dart';
import '../services/task_service.dart';
import '../services/keep_alive_service.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  DataManagementPageState createState() => DataManagementPageState();
}

class DataManagementPageState extends State<DataManagementPage>
    with WidgetsBindingObserver {
  Map<String, dynamic> _fileInfo = {};
  bool _isLoading = false;
  String _currentVersion = '';
  // 是否在最近任务中隐藏 PowerBox 卡片（原生侧持久化并立即生效）
  bool _hideFromRecents = false;
  // 是否开启 1x1 透明悬浮窗保活
  bool _floatingKeepAlive = false;
  // 用户去授权悬浮窗后，返回 App 时自动补开开关
  bool _pendingFloatingEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadFileInfo();
    _loadVersionInfo();
    _loadKeepAliveSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _pendingFloatingEnable) {
      _pendingFloatingEnable = false;
      _tryEnableFloatingAfterPermission();
    }
  }

  /// 加载桌面小组件保活相关设置
  Future<void> _loadKeepAliveSettings() async {
    final hideFromRecents = await TaskService.isHideFromRecents();
    final floatingKeepAlive = await KeepAliveService.isFloatingKeepAlive();
    if (!mounted) return;
    setState(() {
      _hideFromRecents = hideFromRecents;
      _floatingKeepAlive = floatingKeepAlive;
    });
  }

  /// 切换「隐藏最近任务卡片」。
  ///
  /// 开启前先确认：应用无法替用户锁定后台，锁定需要手动在最近任务里完成；
  /// 隐藏后最近任务看不到本应用，只能从桌面图标回到本页关闭。
  Future<void> _setHideFromRecents(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('隐藏后台任务卡片'),
          content: Text(
            '开启后，最近任务中将不再显示 PowerBox 卡片。\n\n'
            '建议先在最近任务里把 PowerBox 卡片下拉锁定，再开启本开关；'
            '隐藏本身不会阻止系统清理后台。\n\n'
            '隐藏后如需关闭，请从桌面图标进入「设置」本页操作。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('开启'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _hideFromRecents = value;
    });
    final applied = await TaskService.setHideFromRecents(value);
    if (!mounted) return;
    if (!applied) {
      showToast(context, '设置已保存，重启 App 后生效');
    } else {
      showToast(
        context,
        value ? '已隐藏，最近任务中将不再显示 PowerBox' : '已恢复在最近任务中显示',
      );
    }
  }

  /// 从悬浮窗授权页返回后自动重试开启，避免用户还要再点一次开关。
  Future<void> _tryEnableFloatingAfterPermission() async {
    final granted = await KeepAliveService.isOverlayPermissionGranted();
    if (!mounted) return;
    if (!granted) {
      showToast(context, '未授予显示悬浮窗权限');
      return;
    }
    final applied = await KeepAliveService.setFloatingKeepAlive(true);
    if (!mounted) return;
    if (applied) {
      setState(() => _floatingKeepAlive = true);
      showToast(context, '已开启透明悬浮窗保活');
    } else {
      showToast(context, '开启失败，请重试');
    }
  }

  /// 切换 1x1 透明悬浮窗保活。
  ///
  /// 开启前先确认：悬浮窗只能降低被杀概率，且需要用户手动授予显示悬浮窗权限；
  /// 没有权限时先跳系统授权页，返回后由 didChangeAppLifecycleState 自动补开。
  Future<void> _setFloatingKeepAlive(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('透明悬浮窗保活'),
          content: Text(
            '开启后会在屏幕左上角保留一个 1x1 的透明窗口，'
            '用于降低应用被系统清理的概率。\n\n'
            '这不能保证进程不被杀，只是降低概率；需要授予「显示悬浮窗」权限，'
            '部分系统会提示「PowerBox 正在其他应用上显示」。\n\n'
            '如果不再需要，可以随时在本页关闭。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('开启'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final granted = await KeepAliveService.isOverlayPermissionGranted();
      if (!mounted) return;
      if (!granted) {
        _pendingFloatingEnable = true;
        await KeepAliveService.requestOverlayPermission();
        if (!mounted) return;
        showToast(context, '请授予显示悬浮窗权限，返回后自动开启');
        return;
      }
    }

    final applied = await KeepAliveService.setFloatingKeepAlive(value);
    if (!mounted) return;
    if (applied) {
      setState(() => _floatingKeepAlive = value);
      showToast(
        context,
        value ? '已开启透明悬浮窗保活' : '已关闭透明悬浮窗保活',
      );
    } else {
      showToast(context, '设置失败，请检查悬浮窗权限');
    }
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> loadFileInfo() async {
    final info = await FileStorage.getFileInfo();
    setState(() {
      _fileInfo = info;
    });
  }


  /// 备份恢复入口：弹出「导入 / 导出」选择
  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('备份恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('导入'),
              onTap: () {
                Navigator.pop(dialogContext);
                _importData();
              },
            ),
            ListTile(
              title: Text('导出'),
              onTap: () {
                Navigator.pop(dialogContext);
                _backupAllData();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 导入/导出结果提示：底部显示，停留 3 秒
  void _showBackupToast(String message) {
    showToast(
      context,
      message,
      atBottom: true,
      duration: const Duration(seconds: 3),
    );
  }

  /// 备份打卡和密码数据到公共下载目录，合并成一个 JSON 文件
  Future<void> _backupAllData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 写入存储根目录需要所有文件访问权限
      final granted = await FileStorage.isManageStoragePermissionGranted();
      if (!granted) {
        await FileStorage.requestManageStoragePermission();
        _showBackupToast('请授予所有文件访问权限后重试');
        return;
      }

      final events = await LocalStorage.loadEvents();
      final passwordData = await PasswordStorage.exportPasswordData();
      final path = await FileStorage.backupAll(
        events: events,
        passwordData: passwordData,
      );
      _showBackupToast('数据已备份到下载目录：${path.split('/').last}');
    } catch (e) {
      _showBackupToast('备份失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 导入统一备份文件，兼容旧版单独的打卡/密码文件。
  Future<void> _importData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String contents;
      if (file.path != null) {
        if (!file.path!.toLowerCase().endsWith('.json')) {
          _showBackupToast('请选择 JSON 格式的文件');
          return;
        }
        contents = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        if (!file.name.toLowerCase().endsWith('.json')) {
          _showBackupToast('请选择 JSON 格式的文件');
          return;
        }
        contents = utf8.decode(file.bytes!);
      } else {
        _showBackupToast('无法读取文件内容');
        return;
      }

      final parsed = FileStorage.parseBackupContent(contents);
      final events = parsed['events'] as List<Event>?;
      final passwordData = parsed['passwordData'] as Map<String, String>?;

      if (events == null && passwordData == null) {
        _showBackupToast('文件格式不正确');
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('导入数据'),
          content: Text(
            '将导入：\n'
            '${events != null ? '· 打卡数据 ${events.length} 条\n' : ''}'
            '${passwordData != null ? '· 密码数据\n' : ''}'
            '\n导入会覆盖当前对应的数据，是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('导入'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      if (events != null) {
        await LocalStorage.saveEvents(events);
      }
      if (passwordData != null) {
        await PasswordStorage.importPasswordData(passwordData);
      }

      _showBackupToast(
        '导入成功：'
        '${events != null ? '打卡 ${events.length} 条' : ''}'
        '${events != null && passwordData != null ? '，' : ''}'
        '${passwordData != null ? '密码数据' : ''}',
      );

      // 通知常驻的首页、统计页和密码页重新加载
      notifyDataChanged();
      loadFileInfo();
    } catch (e) {
      _showBackupToast('导入失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 16),
                    _buildFileInfoCard(),
                    SizedBox(height: 24),
                    _buildDataSection(),
                    SizedBox(height: 24),
                    _buildWidgetKeepAliveSection(),
                    SizedBox(height: 24),
                    _buildAboutSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // 返回按钮：从首页设置入口进入时显示
//         if (Navigator.canPop(context)) ...[
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               margin: EdgeInsets.only(right: 10),
//               padding: EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Color(0xFFE1E1E1)),
//               ),
//               child: Icon(
//                 Icons.arrow_back_ios_new,
//                 size: 16,
//                 color: Color(0xFF333333),
//               ),
//             ),
//           ),
//         ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 4),
//               Text(
//                 '导出、导入您的数据',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF999999),
//                 ),
//               ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfoCard() {
    return _buildGroupCard(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF8E8E93),
                ),
                SizedBox(width: 8),
                Text(
                  '数据文件信息',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_fileInfo['exists'] == true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('文件路径', '${_fileInfo['path']}'),
                  SizedBox(height: 8),
                  _buildInfoRow('文件大小', '${_fileInfo['size']} bytes'),
                ],
              )
            else
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '暂无数据文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  /// 分组标题：小号灰字，位于卡片外上方
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }

  /// 统一的白色分组卡片：圆角 + 细边框
  Widget _buildGroupCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE1E1E1)),
      ),
      child: child,
    );
  }

  /// 条目分隔线：左侧与文字对齐（16 + 22 + 16）
  Widget _buildGroupDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      endIndent: 16,
      color: Color(0xFFEFEFF4),
    );
  }

  /// 数据管理：备份恢复（导入 / 导出）
  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('数据管理'),
        _buildGroupCard(
          child: _buildSettingTile(
            icon: Icons.restore,
            title: '备份恢复',
            onTap: _showBackupRestoreDialog,
          ),
        ),
      ],
    );
  }

  /// 桌面小组件保活：隐藏最近任务卡片、透明悬浮窗
  Widget _buildWidgetKeepAliveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('桌面小组件保活'),
        _buildGroupCard(
          child: Column(
            children: [
              _buildSwitchTile(
                icon: Icons.visibility_off_outlined,
                title: '隐藏后台任务卡片',
                subtitle: '从最近任务中隐藏，避免被误滑清理；建议先锁定再开启',
                value: _hideFromRecents,
                onChanged: _setHideFromRecents,
              ),
              _buildGroupDivider(),
              _buildSwitchTile(
                icon: Icons.layers_outlined,
                title: '透明悬浮窗保活',
                subtitle: '保留 1x1 透明窗口降低后台被清理概率，需要显示悬浮窗权限',
                value: _floatingKeepAlive,
                onChanged: _setFloatingKeepAlive,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 带开关的条目：左侧图标 + 标题/副标题 + 右侧 Switch
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Color(0xFF333333),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Color(0xFF333333),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 分组内的单个条目：左侧图标 + 标题/副标题 + 右侧箭头
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
    bool showChevron = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Color(0xFF333333),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor ?? Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFC7C7CC),
              ),
          ],
        ),
      ),
    );
  }

  /// 关于与支持：App 信息 + 检查版本更新
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('关于与支持'),
        _buildGroupCard(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: _buildAppInfoRow(),
              ),
              // App 信息与条目之间的分隔线
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFEFEFF4),
              ),
              _buildSettingTile(
                icon: Icons.code,
                title: 'GitHub 仓库',
                onTap: _openGitHub,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // 检查版本更新：固定在最后一栏
        _buildGroupCard(
          child: _buildSettingTile(
            icon: Icons.system_update,
            title: '检查版本更新',
            onTap: _checkUpdate,
          ),
        ),
      ],
    );
  }

  /// App 信息：左侧图标，右侧标题、副标题、版本上下分布，整体与图标等高
  Widget _buildAppInfoRow() {
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 参考图样式：浅灰底圆角方块内嵌 App 图标
          Container(
            width: 64,
            height: 64,
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PowerBox',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  '打卡 · 统计 · 密码管理',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                Text(
                  _currentVersion.isEmpty ? '版本加载中...' : '版本 $_currentVersion',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 打开 GitHub 仓库
  Future<void> _openGitHub() async {
    final url = Uri.parse('https://github.com/chenzk14/PowerBox.git');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showToast(context, '无法打开 GitHub 链接');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '打开链接失败: $e');
      }
    }
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    showToast(context, '正在检查更新...');
    
    final updateInfo = await UpdateService.checkForUpdate();
    
    if (updateInfo != null && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    } else if (mounted) {
      showToast(context, '当前已是最新版本');
    }
  }
  
  // 移除权限管理方法（Android 11+应用专属目录无需权限）
}
