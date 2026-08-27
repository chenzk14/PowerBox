import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/password_model.dart';

class PasswordStorage {
  static const String _passwordsKey = 'password_entries';
  static const String _encryptionKeyKey = 'encryption_key';
  static const String _encryptionIvKey = 'encryption_iv';

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
    
    final key = Key(base64.decode(keyBase64!));
    _iv = IV(base64.decode(ivBase64!));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  static Future<List<PasswordEntry>> loadPasswords() async {
    await _initialize();
    
    final prefs = await SharedPreferences.getInstance();
    final encryptedData = prefs.getString(_passwordsKey);
    
    if (encryptedData == null || encryptedData.isEmpty) {
      return [];
    }
    
    try {
      final encrypted = Encrypted(base64.decode(encryptedData));
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      final jsonData = json.decode(decrypted) as List<dynamic>;
      
      return jsonData.map((e) => PasswordEntry.fromJson(e)).toList();
    } catch (e) {
      print('解密密码数据失败: $e');
      return [];
    }
  }

  static Future<void> savePasswords(List<PasswordEntry> passwords) async {
    await _initialize();
    
    final prefs = await SharedPreferences.getInstance();
    final jsonData = passwords.map((e) => e.toJson()).toList();
    final jsonString = json.encode(jsonData);
    
    final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
    final encryptedBase64 = base64.encode(encrypted.bytes);
    
    await prefs.setString(_passwordsKey, encryptedBase64);
  }

  static Future<void> addPassword(PasswordEntry entry) async {
    final passwords = await loadPasswords();
    passwords.add(entry);
    await savePasswords(passwords);
  }

  static Future<void> updatePassword(PasswordEntry entry) async {
    final passwords = await loadPasswords();
    final index = passwords.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      passwords[index] = entry;
      await savePasswords(passwords);
    }
  }

  static Future<void> deletePassword(String id) async {
    final passwords = await loadPasswords();
    passwords.removeWhere((e) => e.id == id);
    await savePasswords(passwords);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passwordsKey);
  }
}