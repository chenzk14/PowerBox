import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/express_model.dart';
import '../services/express_storage.dart';
import '../utils/express_parser.dart';
import '../utils/toast_util.dart';
import 'express_rules_page.dart';

/// 新增/编辑快递记录
class ExpressEditPage extends StatefulWidget {
  const ExpressEditPage({super.key, this.entry});

  /// 为空表示新增
  final ExpressEntry? entry;

  @override
  State<ExpressEditPage> createState() => _ExpressEditPageState();
}

class _ExpressEditPageState extends State<ExpressEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _stationController;
  late final TextEditingController _phoneTailController;
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _codeController = TextEditingController(text: entry?.code ?? '');
    _stationController = TextEditingController(text: entry?.station ?? '');
    _phoneTailController = TextEditingController(text: entry?.phoneTail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stationController.dispose();
    _phoneTailController.dispose();
    super.dispose();
  }

  Future<void> _parseFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      if (mounted) showToast(context, '剪贴板为空');
      return;
    }

    final rules = await ExpressStorage.loadEnabledRules();
    final result = parseExpressTextWithRules(text, rules);
    if (result.isEmpty) {
      if (mounted) showToast(context, '未能识别出快递信息');
      return;
    }

    setState(() {
      if (result.name.isNotEmpty) _nameController.text = result.name;
      if (result.code.isNotEmpty) _codeController.text = result.code;
      if (result.station.isNotEmpty) _stationController.text = result.station;
      if (result.phoneTail.isNotEmpty) _phoneTailController.text = result.phoneTail;
    });

    final hint = result.usedRuleName != null
        ? '已使用规则「${result.usedRuleName}」识别，请核对内容'
        : '已识别，请核对内容';
    if (mounted) showToast(context, hint);
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty && code.isEmpty) {
      showToast(context, '请至少填写名称或取件码');
      return;
    }

    setState(() => _saving = true);

    try {
      final entry = (widget.entry ?? ExpressEntry()).copyWith(
        name: name,
        code: code,
        station: _stationController.text.trim(),
        phoneTail: _phoneTailController.text.trim(),
        // 新增/编辑均默认未取件
        isPicked: false,
      );

      if (_isEditing) {
        await ExpressStorage.updateEntry(entry);
      } else {
        await ExpressStorage.addEntry(entry);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '保存失败: $e');
    }
  }

  /// 跳转规则管理
  Future<void> _openRules() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ExpressRulesPage()),
    );
    if (changed == true) {
      // 规则变更无需重新加载，仅提示
      if (mounted) showToast(context, '规则已更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 规则编辑入口（位于原来剪贴板识别卡片的位置）
                    _buildRuleEntryCard(),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    // 底部操作行：左边剪贴板识别，右边保存（放在表单下方，随页面滚动）
                    _buildBottomBar(),
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
        _isEditing ? '编辑快递' : '新增快递',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  /// 规则编辑入口卡片（位于页面顶部）
  Widget _buildRuleEntryCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openRules,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.tune,
              size: 22,
              color: Color(0xFF333333),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剪切板识别不准确？自定义解析规则',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '自定义短信正则，适配不同快递格式',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
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
            label: '名称',
            hint: '如 顺丰、京东-耳机',
          ),
          _buildDivider(),
          _buildTextField(
            controller: _codeController,
            label: '取件码',
            hint: '如 8-2-3012',
          ),
          _buildDivider(),
          _buildTextField(
            controller: _stationController,
            label: '驿站/取件点',
            hint: '如 菜鸟驿站-XX店',
          ),
          _buildDivider(),
          _buildTextField(
            controller: _phoneTailController,
            label: '手机尾号',
            hint: '后四位',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFC7C7CC)),
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  /// 底部操作行：左边剪贴板识别，右边保存
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _parseFromClipboard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF333333),
                  side: const BorderSide(color: Color(0xFFE1E1E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.content_paste, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '从剪贴板识别',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
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
            ),
          ),
        ],
      ),
    );
  }
}
