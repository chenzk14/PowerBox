import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/event_model.dart';

class FileStorage {
  static const String _fileName = 'todo_data.json';
  static const String _backupFileName = 'todo_data_backup.json';
  static const String _exportDirName = 'TodoList';
  // 备份目录固定为 /storage/emulated/0/PowerBox_Backups
  static const String _backupDirName = 'PowerBox_Backups';

  // 与原生 installer 通道复用，用于打开数据文件夹
  static const MethodChannel _channel = MethodChannel('com.powerbox.app/installer');

  // 导出目录固定为 /storage/emulated/0/TodoList
  static Future<Directory> get _exportDirectory async {
    final dir = Directory('/storage/emulated/0/$_exportDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // 备份目录固定为 /storage/emulated/0/PowerBox_Backups
  static Future<Directory> get _backupDirectory async {
    final dir = Directory('/storage/emulated/0/$_backupDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // 内部数据存储目录（应用专属）
  static Future<Directory> get _storageDirectory async {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir;
      }
    } catch (e) {
      print('获取外部存储目录失败: $e');
    }
    final appDir = await getApplicationDocumentsDirectory();
    return appDir;
  }

  // 获取数据文件路径
  static Future<File> get _dataFile async {
    final directory = await _storageDirectory;
    return File('${directory.path}/$_fileName');
  }

  // 获取备份文件路径
  static Future<File> get _backupFile async {
    final directory = await _storageDirectory;
    return File('${directory.path}/$_backupFileName');
  }

  // 保存事件列表到文件
  static Future<void> saveEventsToFile(List<Event> events) async {
    try {
      final directory = await _storageDirectory;
      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = await _dataFile;
      final eventList = events.map((event) => event.toJson()).toList();
      final jsonData = json.encode({
        'version': '1.0',
        'createdAt': DateTime.now().toIso8601String(),
        'events': eventList,
      });
      
      print('保存文件到: ${file.path}');
      await file.writeAsString(jsonData);
      print('文件保存成功，文件大小: ${await file.length()} 字节');
      
      // 同时创建备份
      try {
        final backupFile = await _backupFile;
        await backupFile.writeAsString(jsonData);
        print('备份文件保存成功: ${backupFile.path}');
      } catch (e) {
        print('备份文件保存失败（非致命）: $e');
      }
    } catch (e, stackTrace) {
      print('保存文件失败: $e');
      print('堆栈跟踪: $stackTrace');
      // 如果保存到根目录失败，尝试保存到应用文档目录
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${appDir.path}/$_fileName');
        final eventList = events.map((event) => event.toJson()).toList();
        final jsonData = json.encode({
          'version': '1.0',
          'createdAt': DateTime.now().toIso8601String(),
          'events': eventList,
        });
        await fallbackFile.writeAsString(jsonData);
        print('已回退保存到应用文档目录: ${fallbackFile.path}');
      } catch (fallbackError) {
        print('回退保存也失败: $fallbackError');
        throw Exception('保存数据失败: $e');
      }
    }
  }

  // 从文件加载事件列表
  static Future<List<Event>> loadEventsFromFile() async {
    try {
      // 首先尝试从根目录加载
      final file = await _dataFile;
      if (await file.exists()) {
        print('从根目录加载文件: ${file.path}');
        final contents = await file.readAsString();
        final jsonData = json.decode(contents) as Map<String, dynamic>;
        final eventList = jsonData['events'] as List<dynamic>;
        return eventList.map((eventJson) => Event.fromJson(eventJson)).toList();
      }
      
      // 如果根目录文件不存在，尝试从应用文档目录加载（回退位置）
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackFile = File('${appDir.path}/$_fileName');
      if (await fallbackFile.exists()) {
        print('从应用文档目录加载文件: ${fallbackFile.path}');
        final contents = await fallbackFile.readAsString();
        final jsonData = json.decode(contents) as Map<String, dynamic>;
        final eventList = jsonData['events'] as List<dynamic>;
        return eventList.map((eventJson) => Event.fromJson(eventJson)).toList();
      }
      
      return [];
    } catch (e) {
      print('读取文件失败: $e');
      // 尝试从备份文件恢复
      return await _restoreFromBackup();
    }
  }

  // 从备份文件恢复数据
  static Future<List<Event>> _restoreFromBackup() async {
    try {
      final backupFile = await _backupFile;
      if (await backupFile.exists()) {
        final contents = await backupFile.readAsString();
        final jsonData = json.decode(contents) as Map<String, dynamic>;
        final eventList = jsonData['events'] as List<dynamic>;
        return eventList.map((eventJson) => Event.fromJson(eventJson)).toList();
      }
      return [];
    } catch (e) {
      print('从备份恢复失败: $e');
      return [];
    }
  }

  // 导出密码数据到应用内部存储目录（无需外部存储权限）
  static Future<File> exportPasswordDataToInternalStorage(Map<String, String> data) async {
    try {
      final directory = await _storageDirectory;
      final exportDir = Directory('${directory.path}/TodoList');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final exportFile = File('${exportDir.path}/password_data_export_${DateTime.now().millisecondsSinceEpoch}.json');
      final jsonData = json.encode({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'passwords': data['passwords'],
        'encryptionKey': data['encryptionKey'],
        'encryptionIv': data['encryptionIv'],
      });
      await exportFile.writeAsString(jsonData);
      return exportFile;
    } catch (e) {
      print('导出密码数据失败: $e');
      throw Exception('导出密码数据失败: $e');
    }
  }

  // 导出密码数据到指定文件（加密数据+密钥+IV）
  static Future<File> exportPasswordDataToFile(Map<String, String> data) async {
    try {
      final directory = await _exportDirectory;
      final exportFile = File('${directory.path}/password_data_export_${DateTime.now().millisecondsSinceEpoch}.json');
      final jsonData = json.encode({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'passwords': data['passwords'],
        'encryptionKey': data['encryptionKey'],
        'encryptionIv': data['encryptionIv'],
      });
      await exportFile.writeAsString(jsonData);
      return exportFile;
    } catch (e) {
      print('导出密码数据失败: $e');
      throw Exception('导出密码数据失败: $e');
    }
  }

  // 导出打卡数据到应用内部存储目录（无需外部存储权限）
  static Future<File> exportDataToInternalStorage(List<Event> events) async {
    try {
      final directory = await _storageDirectory;
      final exportDir = Directory('${directory.path}/TodoList');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final exportFile = File('${exportDir.path}/todo_data_export_${DateTime.now().millisecondsSinceEpoch}.json');
      final eventList = events.map((event) => event.toJson()).toList();
      final jsonData = json.encode({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'totalEvents': events.length,
        'events': eventList,
      });
      await exportFile.writeAsString(jsonData);
      return exportFile;
    } catch (e) {
      print('导出数据失败: $e');
      throw Exception('导出数据失败: $e');
    }
  }

  // 导出数据到指定文件（用于分享或备份）
  static Future<File> exportData(List<Event> events) async {
    try {
      final directory = await _exportDirectory;
      
      final exportFile = File('${directory.path}/todo_data_export_${DateTime.now().millisecondsSinceEpoch}.json');
      
      final eventList = events.map((event) => event.toJson()).toList();
      final jsonData = json.encode({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'totalEvents': events.length,
        'events': eventList,
      });
      
      await exportFile.writeAsString(jsonData);
      return exportFile;
    } catch (e) {
      print('导出数据失败: $e');
      throw Exception('导出数据失败: $e');
    }
  }

  // 从外部文件导入数据
  static Future<List<Event>> importData(File file) async {
    try {
      final contents = await file.readAsString();
      final jsonData = json.decode(contents) as Map<String, dynamic>;
      final eventList = jsonData['events'] as List<dynamic>;
      final events = eventList.map((eventJson) => Event.fromJson(eventJson)).toList();
      
      // 保存导入的数据
      await saveEventsToFile(events);
      return events;
    } catch (e) {
      print('导入数据失败: $e');
      throw Exception('导入数据失败: 文件格式不正确');
    }
  }

  // 检查文件是否存在
  static Future<bool> dataFileExists() async {
    final file = await _dataFile;
    return await file.exists();
  }

  // 获取文件信息
  static Future<Map<String, dynamic>> getFileInfo() async {
    final file = await _dataFile;
    if (await file.exists()) {
      final stat = await file.stat();
      return {
        'exists': true,
        'path': file.path,
        'size': stat.size,
        'modified': stat.modified,
      };
    }
    return {'exists': false};
  }

  /// 是否已获得所有文件访问权限（Android 11+）
  static Future<bool> isManageStoragePermissionGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('isManageStoragePermissionGranted');
      return granted ?? false;
    } catch (e) {
      print('检查存储权限失败: $e');
      return false;
    }
  }

  /// 跳转到系统设置申请所有文件访问权限
  static Future<void> requestManageStoragePermission() async {
    try {
      await _channel.invokeMethod('requestManageStoragePermission');
    } catch (e) {
      print('申请存储权限失败: $e');
    }
  }

  /// 备份打卡和密码数据到根目录 PowerBox_Backups
  /// 返回生成的两个文件路径
  static Future<List<String>> backupAll({
    required List<Event> events,
    required Map<String, String> passwordData,
  }) async {
    final directory = await _backupDirectory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportedAt = DateTime.now().toIso8601String();

    // 打卡数据
    final eventList = events.map((event) => event.toJson()).toList();
    final eventsFile = File('${directory.path}/todo_data_$timestamp.json');
    await eventsFile.writeAsString(json.encode({
      'version': '1.0',
      'exportedAt': exportedAt,
      'totalEvents': events.length,
      'events': eventList,
    }));

    // 密码数据（加密内容 + 密钥 + IV）
    final passwordFile = File('${directory.path}/password_data_$timestamp.json');
    await passwordFile.writeAsString(json.encode({
      'version': '1.0',
      'exportedAt': exportedAt,
      'passwords': passwordData['passwords'],
      'encryptionKey': passwordData['encryptionKey'],
      'encryptionIv': passwordData['encryptionIv'],
    }));

    return [eventsFile.path, passwordFile.path];
  }

  /// 用系统文件管理器打开数据文件所在目录。
  ///
  /// Android 11+ 无法直接访问应用私有目录（Android/data），
  /// 原生侧会先把文件复制到公共 Download/TodoList，再打开该目录。
  static Future<bool> openDataFolder() async {
    try {
      final file = await _dataFile;
      final folder = file.parent;
      if (!await folder.exists()) return false;
      final result = await _channel.invokeMethod<bool>('openFolder', {
        'path': folder.path,
      });
      return result ?? false;
    } catch (e) {
      print('打开数据文件夹失败: $e');
      return false;
    }
  }

  // 删除数据文件（谨慎使用）
  static Future<void> deleteDataFile() async {
    try {
      final file = await _dataFile;
      if (await file.exists()) {
        await file.delete();
      }
      final backupFile = await _backupFile;
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (e) {
      print('删除文件失败: $e');
    }
  }
}
