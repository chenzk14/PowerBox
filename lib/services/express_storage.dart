import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/express_model.dart';
import '../models/express_parse_rule.dart';

/// 快递数据的本地加密存储
///
/// 与密码数据一样使用 AES-256-CBC 加密后写入 SharedPreferences，
/// 密钥与 IV 单独保存，不与密码数据混用。
class ExpressStorage {
  static const String _expressKey = 'express_entries';
  static const String _expressRulesKey = 'express_parse_rules';
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

  // ========== 自定义解析规则（明文存储，不加密） ==========

  /// 是否已把默认自定义规则写入本地（只写入一次，用户删除后不再恢复）
  static const String _defaultRulesSeededKey = 'express_default_rules_seeded';

  static Future<List<ExpressParseRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    await _seedDefaultCustomRules(prefs);
    return _readRules(prefs);
  }

  static Future<void> saveRules(List<ExpressParseRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeRules(prefs, rules);
  }

  static Future<List<ExpressParseRule>> _readRules(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_expressRulesKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final jsonData = json.decode(raw) as List<dynamic>;
      return jsonData
          .map((e) => ExpressParseRule.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (e) {
      print('加载快递解析规则失败: $e');
      return [];
    }
  }

  static Future<void> _writeRules(
    SharedPreferences prefs,
    List<ExpressParseRule> rules,
  ) async {
    final jsonData = rules.map((e) => e.toJson()).toList();
    await prefs.setString(_expressRulesKey, json.encode(jsonData));
  }

  /// 首次读取规则时，把申通、兔喜这两条常用规则作为普通自定义规则写入。
  /// 之后由用户自行编辑/停用/删除，不会再自动恢复。
  static Future<void> _seedDefaultCustomRules(SharedPreferences prefs) async {
    if (prefs.getBool(_defaultRulesSeededKey) == true) return;

    final rules = await _readRules(prefs);
    for (final rule in _defaultCustomRules()) {
      if (!rules.any((r) => r.id == rule.id)) {
        rules.add(rule);
      }
    }
    await _writeRules(prefs, rules);
    await prefs.setBool(_defaultRulesSeededKey, true);
  }

  /// 默认自定义规则（原系统默认列表中的申通、兔喜规则）
  static List<ExpressParseRule> _defaultCustomRules() {
    return [
      // 申通：凭码到驿站取件
      // 例：【申通快递】凭E-07-6034到东方美地驿站取尾号1237包裹
      //     【申通快递】包裹已到武汉市xx区xxx驿站，请21:00前凭4-5-3594取，地址：xxxx菜鸟驿站
      ExpressParseRule(
        id: 'default_shentong',
        name: '申通快递（凭码取件）',
        enabled: true,
        isBuiltin: false,
        courierPattern: r'申通',
        codePattern: r'凭\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})',
        stationPattern:
            r'(?:到达|到)\s*([^\s，,。；;：:！!]{2,25}?(?:驿站|店|自提点|代收点|快递柜))',
        phoneTailPattern: r'尾号\s*[：:]?\s*(\d{4})',
        priority: 10,
      ),
      // 兔喜生活：取件码 + xxx店
      // 例：【兔喜生活】您有包裹已到达xxxx店，取件码为1-4-4827，地址:xxxxx（xxxxx对面）
      ExpressParseRule(
        id: 'default_tuxi',
        name: '兔喜生活（取件码）',
        enabled: true,
        isBuiltin: false,
        courierPattern: r'兔喜',
        codePattern:
            r'取件码\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})',
        stationPattern:
            r'(?:到达|到)\s*([^\s，,。；;：:！!]{2,25}?(?:驿站|店|自提点|代收点|快递柜))',
        phoneTailPattern: r'尾号\s*[：:]?\s*(\d{4})',
        priority: 11,
      ),
    ];
  }

  static Future<void> addRule(ExpressParseRule rule) async {
    final rules = await loadRules();
    rules.add(rule);
    await saveRules(rules);
  }

  static Future<void> updateRule(ExpressParseRule rule) async {
    final rules = await loadRules();
    final index = rules.indexWhere((e) => e.id == rule.id);
    if (index != -1) {
      rules[index] = rule;
      await saveRules(rules);
    }
  }

  static Future<void> deleteRule(String id) async {
    final rules = await loadRules();
    rules.removeWhere((e) => e.id == id);
    await saveRules(rules);
  }

  /// 获取所有启用的规则，按优先级升序（数字越小越优先）
  static Future<List<ExpressParseRule>> loadEnabledRules() async {
    final rules = await loadRules();
    return rules.where((r) => r.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 系统默认解析规则（硬编码，不可删除，可作为模板复制）。
  /// priority 数字越小越优先；默认规则 priority=100 作为兜底。
  /// 申通、兔喜等常用规则已迁移到自定义规则列表，由用户自行管理。
  static List<ExpressParseRule> loadBuiltinRules() {
    return [
      ExpressParseRule(
        id: 'builtin_default',
        name: '系统默认解析规则',
        enabled: true,
        isBuiltin: true,
        // 取件码：取件码/提货码/取货码/取货凭证/凭证号，以及「凭码取件」
        codePattern:
            r'(?:取件码|提货码|取货码|取货凭证|凭证号|凭)\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})',
        // 驿站：标签匹配、到站名称或关键词匹配
        stationPattern:
            r'(?:取件点|取件地址|驿站名称|自提点|代收点)\s*[：:]?\s*([^\n，,。；;]{2,25})|(?:到达|到)\s*([^\s，,。；;：:！!]{2,25}?(?:驿站|店|自提点|代收点|快递柜|丰巢))|菜鸟驿站|丰巢智能柜|丰巢快递柜|丰巢|快递驿站|快递超市|驿站|自提柜|快递柜|代收点',
        // 地址：地址标签
        addressPattern:
            r'地\s*址\s*(?:是|为)?\s*[：:]?\s*([^\n，,。；;]{4,60})',
        // 手机尾号：尾号/后四位
        phoneTailPattern:
            r'(?:手机号?尾号|尾号|手机号?末四位)\s*[：:]?\s*(\d{4})|手机号?后四位\s*[：:]?\s*(\d{4})',
        // 快递名：关键词包含
        courierPattern:
            r'顺丰|中通|圆通|申通|韵达|极兔|京东|德邦|中国邮政|邮政|EMS|兔喜|菜鸟|百世|天天|宅急送|跨越',
        priority: 100,
      ),
    ];
  }
}
