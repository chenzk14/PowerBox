import 'package:flutter/material.dart';
import 'battery_page.dart';
import 'express_page.dart';

/// 常用工具：二级入口页，目前只有快递管理
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  void _openExpress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpressPage()),
    );
  }

  void _openBattery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatteryPage()),
    );
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: _buildToolList(context),
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
            '常用工具',
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

  Widget _buildToolList(BuildContext context) {
    // 卡片列表：一行一个，不包裹
    return Column(
      children: [
        _buildToolTile(
          context,
          icon: Icons.local_shipping_outlined,
          title: '快递管理',
          subtitle: '记录取件码与收货地址',
          onTap: () => _openExpress(context),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: Icons.battery_charging_full_outlined,
          title: '电池信息',
          subtitle: '校准容量，添加桌面电池小组件',
          onTap: () => _openBattery(context),
        ),
      ],
    );
  }

  Widget _buildToolTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: const Color(0xFF333333),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
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
}
