import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/express_model.dart';

/// 快递数据的本地加密存储
///
/// 与密码数据一样使用 AES-256-CBC 加密后写入 SharedPreferences，
/// 密钥与 IV 单独保存，不与密码数据混用。
class ExpressStorage {
  static const String _expressKey = 'express_entries';
  static const String _encryptionKeyKey = 'express_encryption_key';
  static const String _encryptionIvKey = 'express_encryption_iv';

  static late Encrypter _encrypter;
  static late IV _iv;

  static Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    String? keyBase64 = prefs.getString(_encryptionKeyKey);
    String? ivBase64 = prefs.getString(_encryptionIvKey);

    if (keyBase64 == null || ivBase64 == null) {
      final key = Key.fromSecureRandom(32);
      final iv = IV.fromSecureRandom(16);

      keyBase64 = base64.encode(key.bytes);
      ivBase64 = base64.encode(iv.bytes);

      await prefs.setString(_encryptionKeyKey, keyBase64);
      await prefs.setString(_encryptionIvKey, ivBase64);
    }

    final key = Key(base64.decode(keyBase64));
    _iv = IV(base64.decode(ivBase64));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  static Future<List<ExpressEntry>> loadEntries() async {
    await _initialize();

    final prefs = await SharedPreferences.getInstance();
    final encryptedData = prefs.getString(_expressKey);

    if (encryptedData == null || encryptedData.isEmpty) {
      return [];
    }

    try {
      final encrypted = Encrypted(base64.decode(encryptedData));
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      final jsonData = json.decode(decrypted) as List<dynamic>;

      final entries = jsonData.map((e) => ExpressEntry.fromJson(e)).toList();
      // 未取件排前面，同状态按更新时间倒序
      entries.sort((a, b) {
        if (a.isPicked != b.isPicked) return a.isPicked ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return entries;
    } catch (e) {
      print('加载快递数据失败: $e');
      return [];
    }
  }

  static Future<void> saveEntries(List<ExpressEntry> entries) async {
    await _initialize();

    final prefs = await SharedPreferences.getInstance();
    final jsonData = entries.map((e) => e.toJson()).toList();
    final jsonString = json.encode(jsonData);

    final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
    final encryptedBase64 = base64.encode(encrypted.bytes);

    await prefs.setString(_expressKey, encryptedBase64);
  }

  static Future<void> addEntry(ExpressEntry entry) async {
    final entries = await loadEntries();
    entries.add(entry);
    await saveEntries(entries);
  }

  static Future<void> updateEntry(ExpressEntry entry) async {
    final entries = await loadEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      entries[index] = entry;
      await saveEntries(entries);
    }
  }

  static Future<void> deleteEntry(String id) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.id == id);
    await saveEntries(entries);
  }
}
