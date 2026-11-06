import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/express_model.dart';
import '../services/express_storage.dart';
import '../utils/express_parser.dart';
import '../utils/toast_util.dart';

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
  late final TextEditingController _addressController;
  late final TextEditingController _phoneTailController;
  late final TextEditingController _noteController;
  late bool _isPicked;
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _codeController = TextEditingController(text: entry?.code ?? '');
    _stationController = TextEditingController(text: entry?.station ?? '');
    _addressController = TextEditingController(text: entry?.address ?? '');
    _phoneTailController = TextEditingController(text: entry?.phoneTail ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');
    _isPicked = entry?.isPicked ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stationController.dispose();
    _addressController.dispose();
    _phoneTailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _parseFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      if (mounted) showToast(context, '剪贴板为空');
      return;
    }

    final result = parseExpressText(text);
    if (result.isEmpty) {
      if (mounted) showToast(context, '未能识别出快递信息');
      return;
    }

    setState(() {
      if (result.name.isNotEmpty) _nameController.text = result.name;
      if (result.code.isNotEmpty) _codeController.text = result.code;
      if (result.station.isNotEmpty) _stationController.text = result.station;
      if (result.address.isNotEmpty) _addressController.text = result.address;
      if (result.phoneTail.isNotEmpty) _phoneTailController.text = result.phoneTail;
    });

    if (mounted) showToast(context, '已识别，请核对内容');
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
        address: _addressController.text.trim(),
        phoneTail: _phoneTailController.text.trim(),
        note: _noteController.text.trim(),
        isPicked: _isPicked,
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条快递记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ExpressStorage.deleteEntry(widget.entry!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '删除失败: $e');
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPasteCard(),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      _buildDeleteButton(),
                    ],
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
      child: Row(
        children: [
          Text(
            _isEditing ? '编辑快递' : '新增快递',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  /// 剪贴板识别入口：复制快递短信后一键填入
  Widget _buildPasteCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _parseFromClipboard,
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
              Icons.content_paste_search,
              size: 22,
              color: Color(0xFF333333),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '从剪贴板识别',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '复制快递短信后点击，自动填写取件码与地址',
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
            controller: _addressController,
            label: '收货地址',
            hint: '详细地址',
            maxLines: 2,
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
          _buildDivider(),
          _buildTextField(
            controller: _noteController,
            label: '备注',
            hint: '可选',
          ),
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '已取件',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                Switch(
                  value: _isPicked,
                  activeThumbColor: const Color(0xFF333333),
                  onChanged: (value) => setState(() => _isPicked = value),
                ),
              ],
            ),
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

  Widget _buildDeleteButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _confirmDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Color(0xFFE1E1E1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '删除记录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
