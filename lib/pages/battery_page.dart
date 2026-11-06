import 'package:flutter/material.dart';
import '../services/battery_settings.dart';
import '../services/battery_widget_service.dart';
import '../utils/toast_util.dart';

/// 电池信息页：容量校准 + 当前状态查看
///
/// HyperOS 隐藏了电池健康度百分比，系统也不向第三方应用开放
/// 设计容量 / 满充容量，因此这里采用手动校准：
/// - 设计容量：默认 4610mAh（小米 14 标称值），可改
/// - 最大容量：默认等于设计容量，可按实际情况下调
class BatteryPage extends StatefulWidget {
  const BatteryPage({super.key});

  @override
  State<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<BatteryPage> {
  final _designController = TextEditingController();
  final _maxController = TextEditingController();

  Map<String, dynamic>? _liveInfo;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _designController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final design = await BatterySettings.getDesignCapacity();
    final max = await BatterySettings.getMaxCapacity();
    final info = await BatteryWidgetService.getBatteryInfo();
    if (!mounted) return;
    setState(() {
      _designController.text = design.toString();
      _maxController.text = max.toString();
      _liveInfo = info;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final design = int.tryParse(_designController.text.trim());
    final max = int.tryParse(_maxController.text.trim());
    if (design == null || design < 500 || design > 10000) {
      showToast(context, '设计容量需在 500 ~ 10000 mAh 之间');
      return;
    }
    if (max == null || max < 500 || max > design) {
      showToast(context, '最大容量需在 500 ~ 设计容量之间');
      return;
    }

    setState(() => _saving = true);
    await BatterySettings.setDesignCapacity(design);
    await BatterySettings.setMaxCapacity(max);
    await BatteryWidgetService.refreshWidget();
    if (!mounted) return;
    setState(() => _saving = false);
    showToast(context, '已保存，小组件已刷新');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLiveCard(),
                          const SizedBox(height: 16),
                          _buildCalibrationCard(),
                          const SizedBox(height: 16),
                          _buildHintCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Text(
            '电池信息',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  /// 实时状态卡片（对照校准值）
  Widget _buildLiveCard() {
    final info = _liveInfo;
    String fmtMah(dynamic v) =>
        v is num ? '${v.toStringAsFixed(0)} mAh' : '--';
    String fmtC(dynamic v) => v is num ? '${v.toStringAsFixed(1)} ℃' : '--';
    String fmtV(dynamic v) => v is num ? '${(v / 1000).toStringAsFixed(2)} V' : '--';
    String fmtA(dynamic v) => v is num ? '${v.toStringAsFixed(0)} mA' : '未充电';

    return _buildCard(
      title: '当前状态',
      child: Column(
        children: [
          _buildInfoRow('实时容量', fmtMah(info?['chargeCounterMah'])),
          _buildInfoRow('电池温度', fmtC(info?['temperatureC'])),
          _buildInfoRow('电池电压', fmtV(info?['voltageMv'])),
          _buildInfoRow('充电电流', fmtA(info?['currentMa'])),
        ],
      ),
    );
  }

  /// 容量校准卡片
  Widget _buildCalibrationCard() {
    return _buildCard(
      title: '容量校准',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCapacityField(
            label: '设计容量',
            controller: _designController,
            hint: '小米 14 标称 4610',
          ),
          const SizedBox(height: 12),
          _buildCapacityField(
            label: '最大容量（校准值）',
            controller: _maxController,
            hint: '默认等于设计容量，电池老化后可下调',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(_saving ? '保存中...' : '保存并刷新小组件'),
            ),
          ),
        ],
      ),
    );
  }

  /// 使用说明卡片
  Widget _buildHintCard() {
    return _buildCard(
      title: '说明',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintLine('HyperOS 隐藏了电池健康度百分比，系统不向第三方应用开放设计容量 / 满充容量。'),
          _buildHintLine('如需精确值，可在拨号盘输入 *#*#6485#*#* 打开电池工程页查看，再手动填入。'),
          _buildHintLine('桌面小组件中的“最大容量比”按 最大容量 / 设计容量 计算，默认 100%。'),
          _buildHintLine('小组件每 30 分钟自动刷新，插拔充电器或点击小组件也会刷新。'),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const Text(
                'mAh',
                style: TextStyle(fontSize: 13, color: Color(0xFFC7C7CC)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B6)),
        ),
      ],
    );
  }

  Widget _buildHintLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.circle, size: 4, color: Color(0xFFC7C7CC)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
