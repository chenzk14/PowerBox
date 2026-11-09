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
import '../services/app_settings.dart';
import '../services/data_refresh_notifier.dart';
import '../services/task_service.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  DataManagementPageState createState() => DataManagementPageState();
}

class DataManagementPageState extends State<DataManagementPage> {
  Map<String, dynamic> _fileInfo = {};
  bool _isLoading = false;
  String _currentVersion = '';
  bool _expressAuthEnabled = true;
  // 是否在最近任务中隐藏 PowerBox 卡片（原生侧持久化并立即生效）
  bool _hideFromRecents = false;
  @override
  void initState() {
    super.initState();
    loadFileInfo();
    _loadVersionInfo();
    _loadToolSettings();
  }

  /// 加载工具相关设置
  Future<void> _loadToolSettings() async {
    final expressAuth = await AppSettings.getExpressAuthEnabled();
    final hideFromRecents = await TaskService.isHideFromRecents();
    if (!mounted) return;
    setState(() {
      _expressAuthEnabled = expressAuth;
      _hideFromRecents = hideFromRecents;
    });
  }

  /// 切换快递页身份验证
  Future<void> _setExpressAuth(bool value) async {
    setState(() {
      _expressAuthEnabled = value;
    });
    await AppSettings.setExpressAuthEnabled(value);
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


  /// 备份打卡和密码数据到根目录 PowerBox_Backups
  Future<void> _backupAllData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 写入存储根目录需要所有文件访问权限
      final granted = await FileStorage.isManageStoragePermissionGranted();
      if (!granted) {
        await FileStorage.requestManageStoragePermission();
        showToast(context, '请授予所有文件访问权限后重试');
        return;
      }

      final events = await LocalStorage.loadEvents();
      final passwordData = await PasswordStorage.exportPasswordData();
      await FileStorage.backupAll(
        events: events,
        passwordData: passwordData,
      );
      showToast(context, '数据已备份到 PowerBox_Backups 文件夹');
    } catch (e) {
      showToast(context, '备份失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.path != null) {
          if (!file.path!.toLowerCase().endsWith('.json')) {
            showToast(context, '请选择 JSON 格式的文件');
            return;
          }

          final fileObj = File(file.path!);
          final events = await FileStorage.importData(fileObj);

          await LocalStorage.saveEvents(events);

          showToast(context, '成功导入 ${events.length} 条数据');

          // 通知常驻的首页和统计页重新加载
          notifyDataChanged();

          loadFileInfo();
        } else {
          if (file.bytes != null) {
            if (!file.name.toLowerCase().endsWith('.json')) {
              showToast(context, '请选择 JSON 格式的文件');
              return;
            }

            final data = utf8.decode(file.bytes!);
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            List<Event> events;
            
            if (jsonData.containsKey('events')) {
              final eventList = jsonData['events'] as List<dynamic>;
              events = eventList.map((e) => Event.fromJson(e)).toList();
            } else if (jsonData is List) {
              events = (jsonData as List).map((e) => Event.fromJson(e)).toList();
            } else {
              events = [Event.fromJson(jsonData)];
            }

            await LocalStorage.saveEvents(events);

            showToast(context, '成功导入 ${events.length} 条数据');

            // 通知常驻的首页和统计页重新加载
            notifyDataChanged();

            loadFileInfo();
          } else {
            showToast(context, '无法读取文件内容');
          }
        }
      }
    } catch (e) {
      showToast(context, '导入失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导入数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.event, color: Color(0xFF333333)),
              title: Text('打卡数据'),
              subtitle: Text('从 JSON 文件导入事件记录'),
              onTap: () {
                Navigator.pop(context);
                _importData();
              },
            ),
            ListTile(
              leading: Icon(Icons.lock, color: Color(0xFF333333)),
              title: Text('密码数据'),
              subtitle: Text('从加密文件导入密码数据及密钥'),
              onTap: () {
                Navigator.pop(context);
                _importPasswordData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importPasswordData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final contents = await File(file.path!).readAsString();
          final data = jsonDecode(contents) as Map<String, dynamic>;
          if (!data.containsKey('passwords') ||
              !data.containsKey('encryptionKey') ||
              !data.containsKey('encryptionIv')) {
            showToast(context, '文件格式不正确');
            return;
          }
          await PasswordStorage.importPasswordData(data);
          showToast(context, '密码数据导入成功');
          // 通知常驻的密码页重新加载
          notifyDataChanged();
        } else {
          showToast(context, '无法读取文件内容');
        }
      }
    } catch (e) {
      showToast(context, '导入密码数据失败: $e');
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
                    _buildToolsSection(),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 点击整张卡片用文件管理器打开数据文件所在文件夹
      onTap: _openFileFolder,
      child: _buildGroupCard(
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
                  Spacer(),
                  Text(
                    '导出并打开文件夹',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFC7C7CC),
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
      ),
    );
  }

  /// 导出数据文件并用系统文件管理器打开所在目录。
  /// Android 11+ 无法直接访问应用私有目录，因此原生侧会先复制到公共目录 Download/TodoList。
  Future<void> _openFileFolder() async {
    final opened = await FileStorage.openDataFolder();
    if (!mounted) return;
    if (opened) {
      showToast(context, '数据文件已复制到 下载/TodoList');
    } else {
      showToast(context, '未能打开文件管理器');
    }
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

  /// 数据管理：备份、导入
  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('数据管理'),
        _buildGroupCard(
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.backup_outlined,
                title: '备份数据',
                onTap: _backupAllData,
              ),
              _buildGroupDivider(),
              _buildSettingTile(
                icon: Icons.file_download,
                title: '导入数据',
                onTap: _showImportDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 工具：快递页身份验证、隐藏最近任务卡片
  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('工具'),
        _buildGroupCard(
          child: Column(
            children: [
              _buildSwitchTile(
                icon: Icons.fingerprint,
                title: '快递页身份验证',
                subtitle: '进入快递管理时验证身份，关闭后直接查看',
                value: _expressAuthEnabled,
                onChanged: _setExpressAuth,
              ),
              _buildGroupDivider(),
              _buildSwitchTile(
                icon: Icons.visibility_off_outlined,
                title: '隐藏后台任务卡片',
                subtitle: '从最近任务中隐藏，避免被误滑清理；建议先锁定再开启',
                value: _hideFromRecents,
                onChanged: _setHideFromRecents,
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
