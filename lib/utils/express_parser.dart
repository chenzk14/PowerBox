import '../models/express_parse_rule.dart';

/// 快递短信/通知文本解析结果
///
/// [usedRuleName] 记录实际生效的自定义规则名称；
/// 内置规则解析时为 null， UI 可据此显示“是否使用了自定义规则”。
class ExpressParseResult {
  final String name;
  final String code;
  final String station;
  final String address;
  final String phoneTail;
  final String? usedRuleName;

  const ExpressParseResult({
    this.name = '',
    this.code = '',
    this.station = '',
    this.address = '',
    this.phoneTail = '',
    this.usedRuleName,
  });

  bool get isEmpty =>
      name.isEmpty && code.isEmpty && station.isEmpty && address.isEmpty && phoneTail.isEmpty;

  ExpressParseResult copyWith({
    String? name,
    String? code,
    String? station,
    String? address,
    String? phoneTail,
    String? usedRuleName,
  }) {
    return ExpressParseResult(
      name: name ?? this.name,
      code: code ?? this.code,
      station: station ?? this.station,
      address: address ?? this.address,
      phoneTail: phoneTail ?? this.phoneTail,
      usedRuleName: usedRuleName ?? this.usedRuleName,
    );
  }
}

/// 常见快递公司关键词，用于从文本里推断来源
const List<String> _courierNames = [
  '顺丰',
  '中通',
  '圆通',
  '申通',
  '韵达',
  '极兔',
  '京东',
  '德邦',
  '中国邮政',
  '邮政',
  'EMS',
  '兔喜',
  '菜鸟',
  '百世',
  '天天',
  '宅急送',
  '跨越',
];

/// 驿站/取件点的通用名称
const String _stationNames =
    r'(?:菜鸟驿站|丰巢智能柜|丰巢快递柜|丰巢|快递驿站|快递超市|驿站|自提柜|快递柜|代收点)';

/// 从快递短信、通知或任意文本中提取取件码、驿站、地址、手机尾号。
///
/// 只做尽力而为的提取，结果允许为空，由用户在编辑页手动补全。
ExpressParseResult parseExpressText(String raw) {
  return parseExpressTextWithRules(raw, const []);
}

/// 带自定义规则的解析入口。
///
/// 策略：
/// 1. 按优先级遍历启用的自定义规则；
/// 2. 对每条规则，逐字段尝试匹配。只要该规则至少提取到一个非空字段，
///    即认为规则匹配成功；
/// 3. 规则匹配成功后，用规则提取到的字段；缺失的字段再用内置规则补全；
/// 4. 所有自定义规则都不匹配时，完全使用内置规则。
ExpressParseResult parseExpressTextWithRules(
  String raw,
  List<ExpressParseRule> rules,
) {
  if (raw.trim().isEmpty) return const ExpressParseResult();

  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 去掉【】包裹的头标签，避免驿站名把前面的标签内容一起带上
  final body = text.replaceAll(RegExp(r'【[^】]*】'), ' ');

  // 先尝试内置规则，作为补全用的基础结果
  final builtin = _parseBuiltin(text, body);

  // 按优先级遍历启用的自定义规则
  final enabledRules = rules.where((r) => r.enabled).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  for (final rule in enabledRules) {
    final ruleResult = _applyRule(text, body, rule);
    // 只要规则至少提取到一个字段，就认为匹配成功
    if (ruleResult.code.isNotEmpty ||
        ruleResult.station.isNotEmpty ||
        ruleResult.address.isNotEmpty ||
        ruleResult.phoneTail.isNotEmpty ||
        ruleResult.name.isNotEmpty) {
      // 缺失字段用内置结果补全
      return ruleResult.copyWith(
        name: ruleResult.name.isNotEmpty
            ? ruleResult.name
            : builtin.name,
        code: ruleResult.code.isNotEmpty
            ? ruleResult.code
            : builtin.code,
        station: ruleResult.station.isNotEmpty
            ? ruleResult.station
            : builtin.station,
        address: ruleResult.address.isNotEmpty
            ? ruleResult.address
            : builtin.address,
        phoneTail: ruleResult.phoneTail.isNotEmpty
            ? ruleResult.phoneTail
            : builtin.phoneTail,
      ).copyWith(usedRuleName: rule.name);
    }
  }

  // 没有自定义规则匹配，返回内置结果
  return builtin.copyWith(usedRuleName: null);
}

/// 只用一条规则解析文本，不做内置兜底。
/// 用于规则编辑页实时预览：改正则时立刻看到能提取到什么。
ExpressParseResult parseExpressTextWithSingleRule(
  String raw,
  ExpressParseRule rule,
) {
  if (raw.trim().isEmpty) return const ExpressParseResult();
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final body = text.replaceAll(RegExp(r'【[^】]*】'), ' ');
  return _applyRule(text, body, rule);
}

/// 用单条自定义规则提取字段。每个字段有正则就正则匹配，没有正则或
/// 正则不匹配则留空。
ExpressParseResult _applyRule(
  String text,
  String body,
  ExpressParseRule rule,
) {
  return ExpressParseResult(
    name: rule.courierPattern.isNotEmpty
        ? _matchSingleField(text, rule.courierPattern)
        : '',
    code: rule.codePattern.isNotEmpty
        ? _matchSingleField(text, rule.codePattern)
        : '',
    station: rule.stationPattern.isNotEmpty
        ? _trimPunctuation(_matchSingleField(body, rule.stationPattern))
        : '',
    address: rule.addressPattern.isNotEmpty
        ? _trimPunctuation(_matchSingleField(body, rule.addressPattern))
        : '',
    phoneTail: rule.phoneTailPattern.isNotEmpty
        ? _matchSingleField(text, rule.phoneTailPattern)
        : '',
  );
}

/// 内置规则解析（原有逻辑，不变）
ExpressParseResult _parseBuiltin(String text, String body) {
  final code = _firstMatch(text, [
    RegExp(r'(?:取件码|提货码|取货码|取货凭证)\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})'),
    RegExp(r'凭证号\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})'),
    // 「凭E-07-6034到驿站」「凭4-5-3594取」这类凭码取件
    RegExp(r'凭\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})'),
  ]);

  final phoneTail = _firstMatch(text, [
    RegExp(r'(?:手机号?尾号|尾号|手机号?末四位)\s*[：:]?\s*(\d{4})'),
    RegExp(r'手机号?后四位\s*[：:]?\s*(\d{4})'),
  ]);

  final station = _stationFrom(body);
  final address = _addressFrom(body);
  final name = _courierFrom(text);

  return ExpressParseResult(
    name: name,
    code: code,
    station: _trimPunctuation(station),
    address: _trimPunctuation(address),
    phoneTail: phoneTail,
  );
}

String _stationFrom(String text) {
  // 优先取「取件点：」这类明确标签
  final labeled = _firstMatch(text, [
    RegExp(r'(?:取件点|取件地址|驿站名称|自提点|代收点)\s*[：:]?\s*([^\n，,。；;]{2,25})'),
  ]);
  if (labeled.isNotEmpty) return labeled;

  // 「菜鸟驿站-XX店」这类连字符名称
  final dashed = _firstMatch(text, [
    RegExp('$_stationNames[-－][^\\s，,。；;：:！!】\\[\\]]{1,15}'),
  ]);
  if (dashed.isNotEmpty) return dashed;

  // 「到东方美地驿站」「到达xxxx店」：取「到/到达」后面的完整站点名
  final arrived = _firstMatch(text, [
    RegExp(r'(?:到达|到)\s*([^\s，,。；;：:！!]{2,25}?(?:驿站|店|自提点|代收点|快递柜|丰巢))'),
  ]);
  if (arrived.isNotEmpty) return arrived;

  return _firstMatch(text, [
    RegExp(_stationNames),
  ]);
}

String _addressFrom(String text) {
  final labeled = _firstMatch(text, [
    RegExp(r'地\s*址\s*(?:是|为)?\s*[：:]?\s*([^\n，,。；;]{4,60})'),
  ]);
  if (labeled.isNotEmpty) return labeled;

  // 没有「地址：」标签时，找包含常见地址特征词的片段
  final segments = text.split(RegExp(r'[\n，,。；;！!]'));
  for (final segment in segments) {
    if (segment.contains('验证码') ||
        segment.contains('取件码') ||
        segment.contains('提货码') ||
        segment.contains('取货码') ||
        segment.contains('取件点') ||
        segment.contains('自提点') ||
        segment.contains('代收点') ||
        segment.contains('驿站')) {
      continue;
    }
    if (RegExp(r'(路|街|号|小区|大厦|公寓|广场|园区|栋|单元|室)').hasMatch(segment)) {
      final trimmed = segment.trim();
      if (trimmed.length >= 6 && trimmed.length <= 60) {
        return trimmed;
      }
    }
  }
  return '';
}

/// 单字段正则匹配。有捕获组取第一个非空组，没有取整段匹配。
/// 多个捕获组可能存在不同分支，取第一个非空组才能兼容「A|B」写法。
String _matchSingleField(String text, String pattern) {
  try {
    final regExp = RegExp(pattern);
    final match = regExp.firstMatch(text);
    if (match == null) return '';
    return _firstNonEmptyGroup(match);
  } catch (_) {
    return '';
  }
}

String _firstMatch(String text, List<RegExp> patterns) {
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final cleaned = _firstNonEmptyGroup(match);
      if (cleaned.isNotEmpty) return cleaned;
    }
  }
  return '';
}

/// 有捕获组时取第一个非空组，没有捕获组时取 group(0)。
String _firstNonEmptyGroup(RegExpMatch match) {
  if (match.groupCount == 0) return (match.group(0) ?? '').trim();
  for (var i = 1; i <= match.groupCount; i++) {
    final value = match.group(i);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _courierFrom(String text) {
  for (final courier in _courierNames) {
    if (text.contains(courier)) {
      return courier;
    }
  }
  return '';
}

String _trimPunctuation(String value) {
  return value.replaceAll(RegExp(r'[，,。；;！!\s]+$'), '').trim();
}
