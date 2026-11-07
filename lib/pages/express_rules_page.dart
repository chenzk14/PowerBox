import 'package:flutter/material.dart';
import '../models/express_parse_rule.dart';
import '../services/express_storage.dart';
import '../utils/toast_util.dart';
import '../widgets/circle_action_button.dart';
import '../widgets/swipe_card.dart';
import 'express_rule_edit_page.dart';

/// 快递解析规则管理页面
///
/// 卡片样式和交互与快递管理、密码管理保持一致：
/// - 卡片头部：名称 + 副标题，点击文字区或箭头展开/收起
/// - 右侧胶囊开关：文字在开关内，点击切换启用状态（系统默认规则只读）
/// - 左滑删除（仅自定义规则；系统默认规则不可删除）
/// - 右下角圆形添加按钮
class ExpressRulesPage extends StatefulWidget {
  const ExpressRulesPage({super.key});

  @override
  State<ExpressRulesPage> createState() => _ExpressRulesPageState();
}

class _ExpressRulesPageState extends State<ExpressRulesPage> {
  List<ExpressParseRule> _builtinRules = [];
  List<ExpressParseRule> _customRules = [];
  bool _loading = true;

  /// 已展开的规则 id（同时只展开一个，和快递/密码页一致）
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final builtin = ExpressStorage.loadBuiltinRules();
    final custom = await ExpressStorage.loadRules();
    if (!mounted) return;
    setState(() {
      _builtinRules = builtin;
      _customRules = custom;
      _loading = false;
    });
  }

  Future<void> _toggleEnabled(ExpressParseRule rule) async {
    await ExpressStorage.updateRule(rule.copyWith(enabled: !rule.enabled));
    await _load();
    if (!mounted) return;
    showToast(
      context,
      '规则「${rule.name}」${rule.enabled ? '已停用' : '已启用'}',
    );
  }

  Future<void> _deleteRule(ExpressParseRule rule) async {
    if (rule.isBuiltin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除规则「${rule.name}」吗？'),
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
    await ExpressStorage.deleteRule(rule.id);
    await _load();
    if (!mounted) return;
    showToast(context, '规则已删除');
  }

  /// 把系统默认规则复制为新的自定义规则（打开编辑页，预填内容）
  Future<void> _copyBuiltinToCustom(ExpressParseRule rule) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpressRuleEditPage(
          rule: rule.copyWith(
            id: '',
            isBuiltin: false,
            name: '${rule.name}（副本）',
          ),
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openEdit(ExpressParseRule rule, {bool isBuiltin = false}) async {
    if (isBuiltin) {
      await _copyBuiltinToCustom(rule);
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpressRuleEditPage(rule: rule),
      ),
    );
    if (changed == true) await _load();
  }

  /// 展开/收起某张卡片，同时只保留一个展开（和快递/密码页一致）
  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.clear();
        _expandedIds.add(id);
      }
    });
  }

  /// 已配置字段的摘要；地址正则已从规则编辑中移除，这里不再展示
  String _fieldSummary(ExpressParseRule rule) {
    final fields = <String>[];
    if (rule.codePattern.isNotEmpty) fields.add('取件码');
    if (rule.stationPattern.isNotEmpty) fields.add('驿站');
    if (rule.phoneTailPattern.isNotEmpty) fields.add('尾号');
    if (rule.courierPattern.isNotEmpty) fields.add('快递名');
    return fields.isEmpty ? '未配置任何字段' : fields.join('、');
  }

  /// 折叠副标题：优先级 | 已配置字段
  String _ruleSubtitle(ExpressParseRule rule) {
    return '优先级 ${rule.priority} | ${_fieldSummary(rule)}';
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    // 水平边距由 ListView 统一提供，避免标题比卡片多缩进一段
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 启用/停用胶囊开关：文字在开关内，样式与快递页「待取/已取」开关一致。
  /// interactive 为 false 时（系统默认规则）只展示状态，不响应点击。
  Widget _buildEnabledSwitch(ExpressParseRule rule, {bool interactive = true}) {
    final enabled = rule.enabled;
    final switchBody = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 72,
      height: 32,
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF333333) : const Color(0xFFE1E1E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 文字：启用时在左侧，停用时在右侧（与圆钮位置相反）
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: enabled ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                enabled ? '启用' : '停用',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFF333333),
                ),
              ),
            ),
          ),
          // 圆钮：启用时在右，停用时在左
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!interactive) {
      // 系统默认规则固定启用且不可修改：整体置灰，不响应点击
      return Opacity(
        opacity: 0.38,
        child: IgnorePointer(child: switchBody),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleEnabled(rule),
      child: switchBody,
    );
  }

  Widget _buildDetailSection(ExpressParseRule rule) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE1E1E1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rule.courierPattern.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('快递名正则', rule.courierPattern, Icons.category),
          ],
          if (rule.codePattern.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('取件码正则', rule.codePattern, Icons.confirmation_number),
          ],
          if (rule.stationPattern.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('驿站正则', rule.stationPattern, Icons.storefront_outlined),
          ],
          if (rule.phoneTailPattern.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('手机尾号正则', rule.phoneTailPattern, Icons.phone_iphone),
          ],
          if (rule.courierPattern.isEmpty &&
              rule.codePattern.isEmpty &&
              rule.stationPattern.isEmpty &&
              rule.phoneTailPattern.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '还没有配置任何提取规则',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!rule.isBuiltin) ...[
                // 次操作：编辑（白底细边框），与快递/密码详情按钮一致
                TextButton.icon(
                  onPressed: () => _openEdit(rule),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF333333)),
                  label: const Text(
                    '编辑',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE1E1E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
              // 系统默认规则：主操作，复制为自定义（深色实心）
              if (rule.isBuiltin)
                TextButton.icon(
                  onPressed: () => _copyBuiltinToCustom(rule),
                  icon: const Icon(Icons.copy_all_outlined, size: 18, color: Colors.white),
                  label: const Text(
                    '复制为自定义',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF999999)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF999999),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(ExpressParseRule rule, {bool isBuiltin = false}) {
    final isExpanded = _expandedIds.contains(rule.id);

    // 停用的规则整体降低透明度，和快递页「已取」条目一致
    return Opacity(
      opacity: rule.enabled ? 1 : 0.6,
      child: SwipeCard(
        key: ValueKey(rule.id),
        onEdit: () => _openEdit(rule, isBuiltin: isBuiltin),
        onDelete: isBuiltin ? null : () => _deleteRule(rule),
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E1E1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：名称/副标题 + 启用开关 + 展开箭头
                // 开关不在展开点击区内，避免切换时误触发展开
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _toggleExpand(rule.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ruleSubtitle(rule),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildEnabledSwitch(rule, interactive: !isBuiltin),
                      const SizedBox(width: 4),
                      // 展开箭头：点击也展开/收起
                      InkWell(
                        onTap: () => _toggleExpand(rule.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF999999),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildDetailSection(rule),
                  crossFadeState:
                      isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount:
                          _builtinRules.length + _customRules.length + 2,
                      itemBuilder: (context, index) {
                        // 系统默认分段标题
                        if (index == 0) {
                          return _buildSectionHeader(
                            '系统默认规则',
                            '内置规则固定启用，点击卡片展开可复制为自定义规则',
                          );
                        }
                        // 系统默认规则列表
                        final builtinIndex = index - 1;
                        if (builtinIndex < _builtinRules.length) {
                          return _buildRuleCard(
                            _builtinRules[builtinIndex],
                            isBuiltin: true,
                          );
                        }
                        // 自定义分段标题
                        final customTitleIndex = 1 + _builtinRules.length;
                        if (index == customTitleIndex) {
                          return _buildSectionHeader(
                            '自定义规则',
                            '您添加的规则，可增删改，优先于系统默认规则生效',
                          );
                        }
                        // 自定义规则列表
                        final customIndex = index - customTitleIndex - 1;
                        if (customIndex < _customRules.length) {
                          return _buildRuleCard(
                            _customRules[customIndex],
                            isBuiltin: false,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        ),
      ),
      // 与快递管理、密码管理一致的右下角圆形添加按钮
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CircleActionButton(
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const ExpressRuleEditPage(),
              ),
            );
            if (changed == true) await _load();
          },
          icon: Icons.add,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '解析规则管理',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
