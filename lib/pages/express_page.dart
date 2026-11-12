import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/express_model.dart';
import '../services/express_storage.dart';
import '../utils/toast_util.dart';
import '../widgets/circle_action_button.dart';
import '../widgets/swipe_card.dart';
import 'express_edit_page.dart';

/// 快递管理：查看取件码与收货地址
class ExpressPage extends StatefulWidget {
  const ExpressPage({super.key});

  /// 当前是否有快递页处于打开状态，用于快捷方式重复跳转去重
  static int _visibleCount = 0;
  static bool get isVisible => _visibleCount > 0;

  @override
  State<ExpressPage> createState() => _ExpressPageState();
}

class _ExpressPageState extends State<ExpressPage> {
  List<ExpressEntry> _entries = [];
  bool _loading = true;

  /// 已展开的卡片 id（只展开一个，和密码管理一致）
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    ExpressPage._visibleCount++;
    _loadEntries();
  }

  @override
  void dispose() {
    ExpressPage._visibleCount--;
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await ExpressStorage.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openEdit([ExpressEntry? entry]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ExpressEditPage(entry: entry)),
    );
    if (changed == true) {
      await _loadEntries();
    }
  }

  Future<void> _copyCode(ExpressEntry entry) async {
    if (entry.code.trim().isEmpty) {
      showToast(context, '还没有填写取件码');
      return;
    }
    await Clipboard.setData(ClipboardData(text: entry.code.trim()));
    if (!mounted) return;
    showToast(context, '取件码已复制');
  }

  /// 右滑编辑、左滑删除、点击展开：和密码管理卡片交互一致。
  /// 待取/已取：卡片头部开关，点击即切换。
  Future<void> _togglePicked(ExpressEntry entry) async {
    try {
      await ExpressStorage.updateEntry(entry.copyWith(isPicked: !entry.isPicked));
      await _loadEntries();
      if (!mounted) return;
      showToast(context, entry.isPicked ? '已标记为待取' : '已标记为已取');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '操作失败: $e');
    }
  }

  Future<void> _deleteEntry(ExpressEntry entry) async {
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
      await ExpressStorage.deleteEntry(entry.id);
      await _loadEntries();
      if (!mounted) return;
      showToast(context, '已删除');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '删除失败: $e');
    }
  }

  /// 展开/收起某张卡片，同时只保留一个展开（和密码管理一致）
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      // 与密码管理一样右下角悬浮添加按钮；快递页没有底部导航栏，不用上移
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CircleActionButton(
          onTap: () => _openEdit(),
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
              '快递管理',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        // 没有底部导航，底部留常规边距即可
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: _entries.length,
        itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF333333).withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 36,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有快递记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角 + 添加，或复制短信后一键识别',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(ExpressEntry entry) {
    final isExpanded = _expandedIds.contains(entry.id);

    return Opacity(
      opacity: entry.isPicked ? 0.6 : 1,
      child: SwipeCard(
        key: ValueKey(entry.id),
        onEdit: () => _openEdit(entry),
        onDelete: () => _deleteEntry(entry),
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
                // 头部：取件码大字 + 名称 + 待取开关 + 展开箭头
                // 注意：开关和箭头不在展开 InkWell 里，避免点击误触发展开；
                // 取件码文字和箭头各自的点击都负责展开/收起。
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 取件码大字，和快递名称；展开详情里不重复显示取件码
                      // 点击展开/收起
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _toggleExpand(entry.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPickCodeText(entry),
                              const SizedBox(height: 2),
                              Text(
                                _captionOf(entry),
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
                      _buildPickSwitch(entry),
                      const SizedBox(width: 4),
                      // 展开箭头：点击也展开/收起
                      InkWell(
                        onTap: () => _toggleExpand(entry.id),
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
                  secondChild: _buildDetailSection(entry),
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

  /// 待取/已取开关：文字在开关里面，切换时自动跟随显示
  /// 未选中（待取）：浅灰胶囊，圆钮在左，右侧「待取」文字；
  /// 选中（已取）：深色胶囊，圆钮在右，左侧「已取」文字。
  Widget _buildPickSwitch(ExpressEntry entry) {
    final picked = entry.isPicked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePicked(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 72,
        height: 32,
        decoration: BoxDecoration(
          color: picked ? const Color(0xFF333333) : const Color(0xFFE1E1E1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // 文字：未选中在圆钮对向（右侧）显示「待取」；选中在左侧显示「已取」
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: picked ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  picked ? '已取' : '待取',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: picked
                        ? const Color(0xFFF5F5F5)
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            ),
            // 圆钮：未选中在左，选中在右
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: picked ? Alignment.centerRight : Alignment.centerLeft,
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
      ),
    );
  }

  /// 折叠头里常显的取件码大字；空码用提示语代替
  Widget _buildPickCodeText(ExpressEntry entry) {
    final code = entry.code.trim();
    if (code.isEmpty) {
      return const Text(
        '未填写取件码',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFFC7C7CC),
        ),
      );
    }
    return Text(
      code,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: Color(0xFF333333),
      ),
    );
  }

  /// 折叠副标题：名称 | 驿站；驿站为空只显示名称；
  /// 名称为空时 displayTitle 内部已经兜底成驿站，避免重复显示驿站
  String _captionOf(ExpressEntry entry) {
    final name = entry.name.trim();
    final station = entry.station.trim();
    if (name.isEmpty) return entry.displayTitle;
    if (station.isEmpty) return name;
    return '$name | $station';
  }

  /// 展开详情区：驿站/尾号 + 复制取件码/编辑（取件码常显在卡片头部，此处不重复）
  Widget _buildDetailSection(ExpressEntry entry) {
    // 详情里有没有真正要显示的字段，没有就压紧布局
    final hasDetail = entry.station.trim().isNotEmpty ||
        entry.phoneTail.trim().isNotEmpty;
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
          SizedBox(height: hasDetail ? 12 : 2),
          if (entry.station.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow('驿站', entry.station.trim(), Icons.storefront_outlined),
          ],
          if (entry.phoneTail.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              '手机尾号',
              '尾号 ${entry.phoneTail.trim()}',
              Icons.phone_iphone,
            ),
          ],
          SizedBox(height: hasDetail ? 16 : 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 主操作：复制取件码（深色实心）
              TextButton.icon(
                onPressed: () => _copyCode(entry),
                icon: const Icon(Icons.copy_all_outlined, size: 18, color: Colors.white),
                label: const Text(
                  '复制取件码',
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
              const SizedBox(width: 8),
              // 次操作：编辑（白底细边框）
              TextButton.icon(
                onPressed: () => _openEdit(entry),
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
          ),
        ],
      ),
    );
  }

  /// 详情行：图标 + 标签 + 值
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
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
