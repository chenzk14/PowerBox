import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  // GitHub仓库信息
  static const String _owner = 'chenzk14';
  static const String _repo = 'todo_list_app';
  
  // GitHub Releases API地址
  static String get _apiUrl => 
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  
  // MethodChannel for Android native code
  static const MethodChannel _channel = MethodChannel('com.example.punch_card_app/installer');

  /// 检查是否有新版本
  /// 返回null表示没有更新，返回Map表示有更新
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 获取当前App版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('当前版本: $currentVersion');
      
      // 从GitHub Releases获取最新版本信息
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(Duration(seconds: 10));
      
      print('GitHub API响应状态: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('检查更新失败: ${response.statusCode}');
        return null;
      }
      
      final data = json.decode(response.body);
      
      // 解析最新版本号（去掉开头的V或v）
      final latestVersion = data['tag_name'].toString().replaceFirst(RegExp(r'^[Vv]'), '');
      print('最新版本: $latestVersion');
      
      // 比较版本号
      final hasUpdate = _isNewerVersion(latestVersion, currentVersion);
      print('是否有更新: $hasUpdate');
      
      if (hasUpdate) {
        // 获取APK下载链接
        String? downloadUrl;
        String? fileName;
        
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          final asset = data['assets'][0];
          downloadUrl = asset['browser_download_url'];
          fileName = asset['name'];
        }
        
        return {
          'version': latestVersion,
          'name': data['name'] ?? '新版本',
          'body': data['body'] ?? '暂无更新说明',
          'downloadUrl': downloadUrl,
          'fileName': fileName,
          'publishedAt': data['published_at'],
        };
      }
      
      return null; // 没有新版本
    } catch (e) {
      print('检查更新异常: $e');
      return null;
    }
  }

  /// 比较版本号，判断version1是否比version2新
  static bool _isNewerVersion(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();
    
    // 补齐长度
    while (v1Parts.length < v2Parts.length) {
      v1Parts.add(0);
    }
    while (v2Parts.length < v1Parts.length) {
      v2Parts.add(0);
    }
    
    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] > v2Parts[i]) return true;
      if (v1Parts[i] < v2Parts[i]) return false;
    }
    
    return false;
  }

  /// 下载APK文件
  /// 返回下载后的文件路径
  static Future<String?> downloadApk(
    String downloadUrl,
    String fileName,
    Function(double)? onProgress,
  ) async {
    try {
      // 获取应用专属目录（Android 7.0+ FileProvider可访问）
      Directory tempDir;
      if (Platform.isAndroid) {
        // 使用应用专属外部存储目录
        final appDir = await getExternalStorageDirectory();
        tempDir = appDir ?? await getTemporaryDirectory();
      } else {
        tempDir = await getTemporaryDirectory();
      }
      final savePath = '${tempDir.path}/$fileName';
      
      // 创建HTTP请求
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        print('下载失败: ${response.statusCode}');
        return null;
      }
      
      // 获取文件大小
      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      // 创建文件
      final file = File(savePath);
      final sink = file.openWrite();
      
      // 监听下载进度
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        
        if (contentLength > 0 && onProgress != null) {
          onProgress(receivedBytes / contentLength);
        }
      }
      
      await sink.flush();
      await sink.close();
      
      print('下载完成: $savePath');
      return savePath;
    } catch (e) {
      print('下载异常: $e');
      return null;
    }
  }

  /// 安装APK文件
  static Future<bool> installApk(String filePath) async {
    try {
      // 尝试使用原生Intent安装
      if (Platform.isAndroid) {
        try {
          final result = await _channel.invokeMethod('installApk', {'filePath': filePath});
          if (result == true) {
            return true;
          }
        } catch (e) {
          print('原生安装失败，尝试open_file: $e');
        }
      }
      
      // 回退到open_file
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      print('安装异常: $e');
      return false;
    }
  }

  /// 显示更新对话框
  static void showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(updateInfo: updateInfo),
    );
  }
}

/// 更新对话框组件
class _UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  
  const _UpdateDialog({required this.updateInfo});
  
  @override
  _UpdateDialogState createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _status = '准备下载...';
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 更新图标
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update,
                size: 32,
                color: Color(0xFF4A7CF7),
              ),
            ),
            SizedBox(height: 16),
            
            // 标题
            Text(
              '发现新版本',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 8),
            
            // 版本信息
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'V${widget.updateInfo['version']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A7CF7),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // 更新说明
            if (widget.updateInfo['body'] != null &&
                widget.updateInfo['body'].toString().isNotEmpty)
              Container(
                width: double.maxFinite,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.updateInfo['body'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ),
            SizedBox(height: 16),
            
            // 下载进度
            if (_isDownloading) ...[
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A7CF7)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9AB0),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
            
            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isDownloading ? null : () => Navigator.pop(context),
                    child: Text(
                      '稍后更新',
                      style: TextStyle(color: Color(0xFF9A9AB0)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDownloading ? null : _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A7CF7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isDownloading ? '下载中...' : '立即更新'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload() async {
    final downloadUrl = widget.updateInfo['downloadUrl'];
    final fileName = widget.updateInfo['fileName'] ?? 'app-release.apk';
    
    if (downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载链接不可用')),
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = '正在下载...';
    });
    
    final filePath = await UpdateService.downloadApk(
      downloadUrl,
      fileName,
      (progress) {
        setState(() {
          _progress = progress;
          _status = '正在下载 ${(progress * 100).toStringAsFixed(1)}%';
        });
      },
    );
    
    if (filePath != null) {
      setState(() {
        _status = '下载完成，准备安装...';
      });
      
      // 安装APK
      final installed = await UpdateService.installApk(filePath);
      
      if (!installed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败，请手动安装')),
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _status = '下载失败，请重试';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败，请检查网络连接')),
        );
      }
    }
  }
}
