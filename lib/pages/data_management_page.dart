import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../models/event_model.dart';
import '../services/file_storage.dart';
import '../services/local_storage.dart';
import '../utils/toast_util.dart';
import '../services/update_service.dart';
import 'password_manager_page.dart';

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
  static const MethodChannel _channel = MethodChannel('com.example.punch_card_app/installer');

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
    // Android 11+ 先检查权限，没有权限则弹框引导
    if (Platform.isAndroid) {
      final hasPermission = await _channel.invokeMethod('isManageStoragePermissionGranted');
      if (hasPermission != true) {
        _showPermissionDialog();
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final events = await LocalStorage.loadEvents();
      if (events.isEmpty) {
        showToast(context, '没有数据可以导出');
        return;
      }

      final exportFile = await FileStorage.exportData(events);
      showToast(context, '数据已导出到: ${exportFile.path}');
    } catch (e) {
      showToast(context, '导出失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('需要权限'),
        content: Text('导出文件需要"所有文件访问"权限，请在设置中开启'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _channel.invokeMethod('requestManageStoragePermission');
            },
            child: Text('去设置'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
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
                    SizedBox(height: 16),
                    _buildActionGrid(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '数据管理',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '导出、导入您的数据',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9A9AB0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF4A7CF7),
                ),
              ),
              SizedBox(width: 10),
              Text(
                '数据文件信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
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
                color: Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '暂无数据文件',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9AB0),
                  ),
                ),
              ),
            ),
        ],
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
              color: Color(0xFF9A9AB0),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPasswordManagerCard(),
        SizedBox(height: 16),
        Text(
          '功能操作',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.import_export,
                title: '导出数据',
                subtitle: '导出用于分享',
                onTap: _exportData,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.file_download,
                title: '导入数据',
                subtitle: '从文件导入',
                onTap: _importData,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildUpdateCard(),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(), // 占位
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordManagerCard() {
    return GestureDetector(
      onTap: _navigateToPasswordManager,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF9C88FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.password_outlined,
                size: 24,
                color: Color(0xFF9C88FF),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '密码管理',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '安全存储账号密码，支持指纹/密码解锁',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9AB0),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Color(0xFF9A9AB0),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPasswordManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordManagerPage(),
      ),
    );
    // 返回时刷新文件信息（如果有变化）
    loadFileInfo();
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

  Widget _buildUpdateCard() {
    return GestureDetector(
      onTap: _checkUpdate,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.system_update,
                        size: 20,
                        color: Colors.teal,
                      ),
                    ),
                    if (_hasUpdate)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '检查更新',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 2),
            Text(
              _currentVersion.isEmpty ? '加载中...' : 'V$_currentVersion',
              style: TextStyle(
                fontSize: 10,
                color: _hasUpdate ? Colors.red : Color(0xFF9A9AB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF9A9AB0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}