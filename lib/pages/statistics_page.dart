import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/event_model.dart';
import '../services/local_storage.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  StatisticsPageState createState() => StatisticsPageState();
}

class StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  List<Event> _events = [];
  late TabController _tabController;
  List<int> _existingYears = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
    _tabController = TabController(length: 0, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (_existingYears.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> loadEvents() async {
    final events = await LocalStorage.loadEvents();
    setState(() {
      _events = events;
      _existingYears = _getExistingYears();
      if (_existingYears.isNotEmpty) {
        _tabController = TabController(
          length: _existingYears.length,
          vsync: this,
          initialIndex: _existingYears.length - 1,
        );
        _tabController.addListener(() {
          setState(() {});
        });
      }
    });
  }

  List<int> _getExistingYears() {
    final Set<int> years = {};
    for (final event in _events) {
      years.add(event.date.year);
    }
    return years.toList()..sort();
  }

  int _getYearTotal(int year) {
    return _events.where((e) => e.date.year == year).length;
  }

  List<int> _getMonthlyData(int year) {
    final monthlyCounts = List.filled(12, 0);
    for (final event in _events) {
      if (event.date.year == year) {
        monthlyCounts[event.date.month - 1]++;
      }
    }
    return monthlyCounts;
  }

  Map<int, Map<int, Map<int, int>>> _getYearlyMonthlyEventDays() {
    final Map<int, Map<int, Map<int, int>>> result = {};
    for (final event in _events) {
      final year = event.date.year;
      final month = event.date.month;
      final day = event.date.day;
      if (!result.containsKey(year)) {
        result[year] = {};
      }
      if (!result[year]!.containsKey(month)) {
        result[year]![month] = {};
      }
      result[year]![month]![day] = (result[year]![month]![day] ?? 0) + 1;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _events.isEmpty
                  ? _buildEmptyState()
                  : _existingYears.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '打卡统计',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '查看打卡统计数据',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A9AB0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: Color(0xFF4A7CF7),
            ),
          ),
          SizedBox(height: 24),
          Text(
            '暂无打卡记录',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '开始打卡后即可查看统计信息',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF9A9AB0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          height: 34,
          margin: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _existingYears.length,
            separatorBuilder: (context, index) => SizedBox(width: 8),
            itemBuilder: (context, index) {
              final year = _existingYears[index];
              final isSelected = _tabController.index == index;
              return GestureDetector(
                onTap: () {
                  _tabController.animateTo(index);
                },
                child: Container(
                  width: 72,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF4A7CF7) : Colors.white,
                    borderRadius: BorderRadius.circular(90),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$year年',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _existingYears.map((year) {
              return SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  children: [
                    _buildYearSummaryCard(year),
                    SizedBox(height: 12),
                    _buildMonthlyDetailCard(year),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildYearSummaryCard(int year) {
    final total = _getYearTotal(year);
    final monthlyData = _getMonthlyData(year);
    final chartData = List.generate(12, (index) {
      return _ChartData('${index + 1}月', monthlyData[index].toDouble());
    });

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF4A7CF7)),
                      SizedBox(width: 4),
                      Text(
                        '${year}年总计',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9AB0),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$total 次',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_outlined,
                  size: 22,
                  color: Color(0xFF4A7CF7),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: SfCartesianChart(
              margin: EdgeInsets.all(0),
              primaryXAxis: CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10, color: Color(0xFF9A9AB0)),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  color: Color(0xFFF5F6FA),
                  width: 1,
                ),
                axisLine: AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10, color: Color(0xFF9A9AB0)),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.x : point.y 次',
                header: '',
              ),
              series: <CartesianSeries<_ChartData, String>>[
                SplineSeries<_ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (_ChartData data, _) => data.month,
                  yValueMapper: (_ChartData data, _) => data.count,
                  color: Color(0xFF4A7CF7),
                  width: 2,
                  animationDuration: 300,
                  splineType: SplineType.natural,
                  markerSettings: MarkerSettings(
                    isVisible: true,
                    height: 6,
                    width: 6,
                    borderColor: Color(0xFF4A7CF7),
                    borderWidth: 2,
                    color: Colors.white,
                  ),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyDetailCard(int year) {
    final yearlyMonthlyEventDays = _getYearlyMonthlyEventDays();
    final monthlyDays = yearlyMonthlyEventDays[year] ?? {};

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '月度详情',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 12),
          ...List.generate(12, (index) {
            final month = index + 1;
            final dayCounts = monthlyDays[month] ?? {};
            return _buildMonthRow(month, dayCounts);
          }),
        ],
      ),
    );
  }

  Widget _buildMonthRow(int month, Map<int, int> dayCounts) {
    final sortedDays = dayCounts.keys.toList()..sort();
    final totalEvents = dayCounts.values.fold(0, (sum, count) => sum + count);
    final daysText = sortedDays.map((day) {
      final count = dayCounts[day]!;
      return count > 1 ? '$day（${count}次）' : '$day';
    }).join('，');

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        bottom: month == 12 ? 12 : 12,
        left: 0,
        right: 0,
      ),
      decoration: month == 12
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF5F6FA),
                  width: 1,
                ),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: totalEvents > 0
                  ? Color(0xFF4A7CF7).withValues(alpha: 0.1)
                  : Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$month',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: totalEvents > 0 ? Color(0xFF4A7CF7) : Color(0xFF9A9AB0),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$month 月',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (sortedDays.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    '打卡日期：$daysText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9AB0),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: totalEvents > 0
                  ? Color(0xFF4A7CF7).withValues(alpha: 0.1)
                  : Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$totalEvents次',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: totalEvents > 0 ? Color(0xFF4A7CF7) : Color(0xFF9A9AB0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String month;
  final double count;

  _ChartData(this.month, this.count);
}
