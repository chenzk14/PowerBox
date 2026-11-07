import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/express_parse_rule.dart';
import '../services/express_storage.dart';
import '../utils/express_parser.dart';
import '../utils/toast_util.dart';

/// 快递解析规则编辑 / 新增页面
class ExpressRuleEditPage extends StatefulWidget {
  const ExpressRuleEditPage({super.key, this.rule});

  /// 为空表示新增
  final ExpressParseRule? rule;

  @override
  State<ExpressRuleEditPage> createState() => _ExpressRuleEditPageState();
}

class _ExpressRuleEditPageState extends State<ExpressRuleEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _stationController;
  late final TextEditingController _phoneTailController;
  late final TextEditingController _courierController;
  late final TextEditingController _priorityController;
  late final TextEditingController _exampleController;
  bool _saving = false;

  bool get _isEditing => widget.rule != null;

  /// 用当前输入框里的正则组成预览规则
  ExpressParseRule get _currentRule => ExpressParseRule(
        id: 'preview',
        name: '',
        codePattern: _codeController.text.trim(),
        stationPattern: _stationController.text.trim(),
        phoneTailPattern: _phoneTailController.text.trim(),
        courierPattern: _courierController.text.trim(),
      );

  final Map<String, String> _fieldHints = {
    'name': '如 顺丰短信规则、京东快递规则',
    'code': r'取件码[:：]\s*(\d{4,6})',
    'station': r'菜鸟驿站[-－][^\s，。；]{2,20}',
    'address': r'地址[:：]\s*([^\n，。；]{4,60})',
    'phoneTail': r'尾号[:：]\s*(\d{4})',
    'courier': r'(顺丰|中通|圆通|京东|菜鸟)',
  };

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _codeController = TextEditingController(text: rule?.codePattern ?? '');
    _stationController = TextEditingController(text: rule?.stationPattern ?? '');
    _phoneTailController =
        TextEditingController(text: rule?.phoneTailPattern ?? '');
    _courierController = TextEditingController(text: rule?.courierPattern ?? '');
    _priorityController =
        TextEditingController(text: rule?.priority.toString() ?? '0');
    // 示例内容由用户粘贴，不写入规则数据
    _exampleController = TextEditingController();

    // 示例内容或正则变化时，实时刷新解析结果
    for (final controller in [
      _exampleController,
      _codeController,
      _stationController,
      _phoneTailController,
      _courierController,
    ]) {
      controller.addListener(_onPatternChanged);
    }
  }

  void _onPatternChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stationController.dispose();
    _phoneTailController.dispose();
    _courierController.dispose();
    _priorityController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(context, '请输入规则名称');
      return;
    }
    final priority = int.tryParse(_priorityController.text.trim()) ?? 0;

    setState(() => _saving = true);

    try {
      final rule = ExpressParseRule(
        id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        codePattern: _codeController.text.trim(),
        stationPattern: _stationController.text.trim(),
        phoneTailPattern: _phoneTailController.text.trim(),
        courierPattern: _courierController.text.trim(),
        priority: priority,
        createdAt: widget.rule?.createdAt,
        updatedAt: widget.rule?.updatedAt,
      );

      if (_isEditing) {
        await ExpressStorage.updateRule(rule);
        if (mounted) showToast(context, '规则已更新');
      } else {
        await ExpressStorage.addRule(rule);
        if (mounted) showToast(context, '规则已添加');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '保存失败: $e');
    }
  }

  /// 粘贴示例正则到对应字段
  Future<void> _pasteHint(String field) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final hint = _fieldHints[field];
    if (hint == null) return;
    final clipboardText = data?.text;
    if (clipboardText != null && clipboardText.isNotEmpty) {
      // 用户剪贴板有内容时，提示用示例覆盖
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('插入示例正则'),
          content: Text('将把当前字段替换为示例：\n$hint'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
                _setField(field, hint);
              },
              child: const Text('确认'),
            ),
          ],
        ),
      );
    } else {
      _setField(field, hint);
    }
  }

  void _setField(String field, String value) {
    setState(() {
      switch (field) {
        case 'code':
          _codeController.text = value;
          break;
        case 'station':
          _stationController.text = value;
          break;
        case 'phoneTail':
          _phoneTailController.text = value;
          break;
        case 'courier':
          _courierController.text = value;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 只调整示例区域的最大高度，不切换页面结构。
    // 如果切换整块布局，TextField 会被重建、焦点丢失，键盘会立刻收起。
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // 示例固定在顶部：键盘弹起时压缩高度并切换紧凑布局，保证完整显示
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: keyboardVisible ? 250 : 340,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                // 顶部示例文本域：粘贴短信后，修改下方正则即可实时对比解析结果
                child: _buildExampleCard(compact: keyboardVisible),
              ),
            ),
            // 下方表单独立滚动，输入正则时不会把顶部示例一起滚走
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 与新增快递页一致：所有输入框放在同一张白色卡片内，字段间用分割线
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        _isEditing ? '编辑解析规则' : '新增解析规则',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  /// 顶部示例卡片：用户可以粘贴短信内容，并实时查看当前正则的解析结果。
  /// compact 为 true 时（键盘弹起）压缩文本域高度，解析结果改为紧凑标签。
  Widget _buildExampleCard({bool compact = false}) {
    final preview = parseExpressTextWithSingleRule(
      _exampleController.text,
      _currentRule,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: Color(0xFF8E8E93),
              ),
              SizedBox(width: 6),
              Text(
                '示例内容',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 可粘贴的文本域：内容只用于当前页面对比，不写入规则
          TextField(
            controller: _exampleController,
            minLines: compact ? 2 : 3,
            maxLines: compact ? 2 : 6,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF333333),
            ),
            decoration: InputDecoration(
              hintText: '粘贴一条快递短信，修改下方正则可实时对比解析结果',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFC7C7CC),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF333333),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
            child: const Divider(height: 1, color: Color(0xFFE1E1E1)),
          ),
          const Text(
            '实时解析结果',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 4),
          // 键盘弹起时用紧凑标签，保证整张卡片能完整显示
          if (compact)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPreviewChip('取件码', preview.code),
                _buildPreviewChip('驿站', preview.station),
                _buildPreviewChip('手机尾号', preview.phoneTail),
                _buildPreviewChip('快递名', preview.name),
              ],
            )
          else ...[
            _buildPreviewRow('取件码', preview.code),
            _buildPreviewRow('驿站', preview.station),
            _buildPreviewRow('手机尾号', preview.phoneTail),
            _buildPreviewRow('快递名', preview.name),
          ],
        ],
      ),
    );
  }

  /// 紧凑模式下的解析结果标签：匹配到绿色，未匹配灰色
  Widget _buildPreviewChip(String label, String value) {
    final matched = value.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFE8F5E9) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${matched ? value : '未匹配'}',
        style: TextStyle(
          fontSize: 11.5,
          fontFamily: 'monospace',
          color: matched ? const Color(0xFF2E7D32) : const Color(0xFFC7C7CC),
        ),
      ),
    );
  }

  /// 实时解析结果的一行：匹配到显示具体值（绿色），未匹配显示灰色占位
  Widget _buildPreviewRow(String label, String value) {
    final matched = value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
          Expanded(
            child: Text(
              matched ? value : '未匹配',
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                color: matched
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC7C7CC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: '规则名称',
            hint: _fieldHints['name'],
            hintKey: 'name',
          ),
          _buildDivider(),
          _buildTextField(
            controller: _codeController,
            label: '取件码正则',
            hint: _fieldHints['code'],
            hintKey: 'code',
            monospace: true,
            minLines: 3,
            maxLines: 6,
          ),
          _buildDivider(),
          _buildTextField(
            controller: _stationController,
            label: '驿站正则',
            hint: _fieldHints['station'],
            hintKey: 'station',
            monospace: true,
            minLines: 3,
            maxLines: 6,
          ),
          _buildDivider(),
          _buildTextField(
            controller: _phoneTailController,
            label: '手机尾号正则',
            hint: _fieldHints['phoneTail'],
            hintKey: 'phoneTail',
            monospace: true,
            minLines: 3,
            maxLines: 6,
          ),
          _buildDivider(),
          _buildTextField(
            controller: _courierController,
            label: '快递名正则（可选）',
            hint: _fieldHints['courier'],
            hintKey: 'courier',
            monospace: true,
            minLines: 3,
            maxLines: 6,
          ),
          _buildDivider(),
          _buildTextField(
            controller: _priorityController,
            label: '优先级',
            hint: '数字越小越优先，默认 0',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
      ),
    );
  }

  /// 输入框样式与新增快递页完全一致：
  /// 白底卡片、无边框、label 浮动在输入框内、字段间分割线。
  /// 正则类字段用多行文本域，便于查看较长内容。
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? hintKey,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int minLines = 1,
    int maxLines = 1,
    bool monospace = false,
  }) {
    final multiline = maxLines > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType:
            keyboardType ?? (multiline ? TextInputType.multiline : null),
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        textAlignVertical: multiline ? TextAlignVertical.top : null,
        style: TextStyle(
          fontSize: 15,
          color: const Color(0xFF333333),
          fontFamily: monospace ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: const Color(0xFFC7C7CC),
            fontFamily: monospace ? 'monospace' : null,
          ),
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          alignLabelWithHint: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          // 示例按钮放在输入框右侧，不额外占一行
          suffixIcon: hintKey == null
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pasteHint(hintKey),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_paste,
                          size: 16,
                          color: Color(0xFF8E8E93),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '示例',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFEFEFF4),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF333333),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '保存',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
