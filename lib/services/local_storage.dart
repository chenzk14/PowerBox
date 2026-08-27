import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';
import 'file_storage.dart';

class LocalStorage {
  static const String _eventsKey = 'events';

  // 保存事件列表（同时保存到SharedPreferences和文件）
  static Future<void> saveEvents(List<Event> events) async {
    try {
      // 保存到SharedPreferences（兼容旧版本）
      final prefs = await SharedPreferences.getInstance();
      final eventList = events.map((event) => json.encode(event.toJson())).toList();
      await prefs.setStringList(_eventsKey, eventList);
      
      // 保存到文件（新功能）
      await FileStorage.saveEventsToFile(events);
    } catch (e) {
      print('保存数据失败: $e');
      throw Exception('保存数据失败');
    }
  }

  // 从本地加载事件列表（优先从文件加载，如果文件不存在则从SharedPreferences加载）
  static Future<List<Event>> loadEvents() async {
    try {
      // 优先从文件加载
      if (await FileStorage.dataFileExists()) {
        final fileEvents = await FileStorage.loadEventsFromFile();
        if (fileEvents.isNotEmpty) {
          return fileEvents;
        }
      }
      
      // 如果文件不存在或为空，从SharedPreferences加载
      final prefs = await SharedPreferences.getInstance();
      final eventList = prefs.getStringList(_eventsKey);
      if (eventList == null) {
        return [];
      }
      
      // 将SharedPreferences数据迁移到文件
      final events = eventList.map((eventJson) => Event.fromJson(json.decode(eventJson))).toList();
      if (events.isNotEmpty) {
        await FileStorage.saveEventsToFile(events);
      }
      
      return events;
    } catch (e) {
      print('加载数据失败: $e');
      return [];
    }
  }
}