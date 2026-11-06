/// 快递短信/通知文本解析结果
class ExpressParseResult {
  final String name;
  final String code;
  final String station;
  final String address;
  final String phoneTail;

  const ExpressParseResult({
    this.name = '',
    this.code = '',
    this.station = '',
    this.address = '',
    this.phoneTail = '',
  });

  bool get isEmpty =>
      name.isEmpty && code.isEmpty && station.isEmpty && address.isEmpty && phoneTail.isEmpty;
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
  if (raw.trim().isEmpty) return const ExpressParseResult();

  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 去掉【】包裹的头标签，避免驿站名把前面的标签内容一起带上
  final body = text.replaceAll(RegExp(r'【[^】]*】'), ' ');

  final code = _firstMatch(text, [
    RegExp(r'(?:取件码|提货码|取货码|取货凭证)\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})'),
    RegExp(r'凭证号\s*(?:是|为)?\s*[：:]?\s*([0-9A-Za-z][0-9A-Za-z\-]{1,19})'),
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

  return _firstMatch(text, [
    RegExp('$_stationNames[-－][^\\s，,。；;：:！!】\\[\\]]{1,15}'),
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

String _firstMatch(String text, List<RegExp> patterns) {
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      // 部分正则没有捕获组，group(1) 会越界，先判断数量
      final value = match.groupCount >= 1
          ? (match.group(1) ?? '')
          : (match.group(0) ?? '');
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
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
