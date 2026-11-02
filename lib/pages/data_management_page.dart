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

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  DataManagementPageState createState() => DataManagementPageState();
}

class DataManagementPageState extends State<DataManagementPage> {
  Map<String, dynamic> _fileInfo = {};
  bool _isLoading = false;
  String _currentVersion = '';
  bool _hasUpdate = false;
  @override
  void initState() {
    super.initState();
    loadFileInfo();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
    
    // 检查是否有新版本
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      setState(() {
        _hasUpdate = true;
      });
    }
  }

  Future<void> loadFileInfo() async {
    final info = await FileStorage.getFileInfo();
    setState(() {
      _fileInfo = info;
    });
  }


  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final events = await LocalStorage.loadEvents();
      if (events.isEmpty) {
        showToast(context, '没有数据可以导出');
        return;
      }
      final exportFile = await FileStorage.exportDataToInternalStorage(events);
      showToast(context, '数据已导出到: ${exportFile.path}');
    } catch (e) {
      showToast(context, '导出失败: $e');
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

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.event, color: Color(0xFF333333)),
              title: Text('打卡数据'),
              subtitle: Text('导出事件记录为 JSON 文件'),
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
            ),
            ListTile(
              leading: Icon(Icons.lock, color: Color(0xFF333333)),
              title: Text('密码数据'),
              subtitle: Text('导出加密后的密码数据及密钥'),
              onTap: () {
                Navigator.pop(context);
                _exportPasswordData();
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _exportPasswordData() async {
    try {
      final data = await PasswordStorage.exportPasswordData();
      final exportFile = await FileStorage.exportPasswordDataToInternalStorage(data);
      showToast(context, '密码数据已导出到: ${exportFile.path}');
    } catch (e) {
      showToast(context, '导出密码数据失败: $e');
    }
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
                  SizedBox(height: 8),
                  _buildInfoRow('修改时间', '${_fileInfo['modified']}'),
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

  /// 数据管理：导入、导出
  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('数据管理'),
        _buildGroupCard(
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.import_export,
                title: '导出数据',
                subtitle: '导出为 JSON 文件',
                onTap: _showExportDialog,
              ),
              _buildGroupDivider(),
              _buildSettingTile(
                icon: Icons.file_download,
                title: '导入数据',
                subtitle: '从 JSON 文件导入',
                onTap: _showImportDialog,
              ),
            ],
          ),
        ),
      ],
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
            subtitle: _hasUpdate ? '发现新版本，点击更新' : '检查是否有新版本',
            subtitleColor: _hasUpdate ? Colors.red : null,
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
      setState(() {
        _hasUpdate = true;
      });
      UpdateService.showUpdateDialog(context, updateInfo);
    } else if (mounted) {
      setState(() {
        _hasUpdate = false;
      });
      showToast(context, '当前已是最新版本');
    }
  }
  
  // 移除权限管理方法（Android 11+应用专属目录无需权限）
}
