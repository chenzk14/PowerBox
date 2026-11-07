import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/event_model.dart';
import '../services/data_refresh_notifier.dart';
import '../services/local_storage.dart';
import '../utils/toast_util.dart';
import '../widgets/app_top_bar.dart';
import 'statistics_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];

  void _showMonthPicker() async {
    int selectedYear = _focusedDay.year;
    int selectedMonth = _focusedDay.month;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '选择年月',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedYear--;
                            });
                          },
                          icon: Icon(Icons.chevron_left, color: Color(0xFF333333)),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF333333).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selectedYear 年',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedYear++;
                            });
                          },
                          icon: Icon(Icons.chevron_right, color: Color(0xFF333333)),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == selectedMonth;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedMonth = month;
                            });
                          },
                          child: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF333333) : Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$month月',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : Color(0xFF333333),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              '取消',
                              style: TextStyle(color: Color(0xFF999999)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                final now = DateTime.now();
                                selectedYear = now.year;
                                selectedMonth = now.month;
                              });
                            },
                            child: Text(
                              '回到当前',
                              style: TextStyle(color: Color(0xFF333333)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _focusedDay = DateTime(selectedYear, selectedMonth, 1);
                                _selectedDay = null;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF333333),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('确定'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _loadEvents();
    // 导入数据等操作完成后，常驻的首页需要主动刷新
    dataRefreshNotifier.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    _loadEvents();
  }

  @override
  void dispose() {
    dataRefreshNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final events = await LocalStorage.loadEvents();
    setState(() {
      _events = events;
      _events.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _saveEvents() async {
    await LocalStorage.saveEvents(_events);
  }

  List<Event> _getEventsForDay(DateTime day) {
    final eventsForDay = _events.where((event) => isSameDay(event.date, day)).toList();
    eventsForDay.sort((a, b) => b.date.compareTo(a.date));
    return eventsForDay;
  }

  /// 日历单元格：
  /// 默认无背景；存在事件时为整块矩形背景（圆角 4px），底部显示事件条数。
  Widget _buildCalendarDayCell(
    DateTime date,
    List<Event> events, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final eventCount = events.length;
    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      // 选中态使用主题蓝色
      backgroundColor = Color(0xFF333333);
      textColor = Colors.white;
    } else if (eventCount > 0) {
      // 存在事件：黑白风下使用浅灰底 + 深灰文字
      backgroundColor = Color(0xFF333333).withValues(alpha: 0.1);
      textColor = Color(0xFF333333);
    } else {
      // 默认无背景
      backgroundColor = Colors.transparent;
      textColor = isToday ? Color(0xFF333333) : Color(0xFF333333);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 取单元格的较短边并留出 4px 间隙，保证背景始终是正方形，
        // 避免加入底部小字后矩形被拉长导致内容显得被挤压
        final side = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight) -
            4;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (eventCount > 0)
                    Text(
                      '事件 x $eventCount',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.9),
                        fontSize: 8,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _getTotalEvents() {
    final target = _focusedDay;
    return _events.where((e) => e.date.year == target.year && e.date.month == target.month).length;
  }

  int _getLastMonthEvents() {
    final target = _focusedDay;
    final lastMonth = DateTime(target.year, target.month - 1, 1);
    return _events.where((e) => e.date.year == lastMonth.year && e.date.month == lastMonth.month).length;
  }

  String _getMonthComparison() {
    final current = _getTotalEvents();
    final last = _getLastMonthEvents();
    // 与上月对比改为次数差值，不再显示百分比
    final diff = current - last;
    if (diff > 0) return '+$diff 次';
    if (diff < 0) return '$diff 次';
    return '0 次';
  }

  bool _isComparisonUp() {
    final current = _getTotalEvents();
    final last = _getLastMonthEvents();
    return current >= last;
  }

  // 打开统计页面
  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StatisticsPage()),
    );
  }

  void _punchCard() {
    final punchDate = _selectedDay ?? DateTime.now();
    final newEvent = Event(
      name: '未命名事件',
      date: DateTime(punchDate.year, punchDate.month, punchDate.day,
          DateTime.now().hour, DateTime.now().minute, DateTime.now().second),
      status: EventStatus.scheduled,
    );
    setState(() {
      _events.add(newEvent);
      _events.sort((a, b) => b.date.compareTo(a.date));
    });
    _saveEvents();
  }

  Future<void> _editEvent(Event event) async {
    final controller = TextEditingController(text: event.name);
    final editedName = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '修改事件',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入事件名称',
                  hintStyle: TextStyle(color: Color(0xFF999999)),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF333333), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF333333),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      '确定',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (editedName != null && editedName.isNotEmpty) {
      setState(() {
        final index = _events.indexOf(event);
        _events[index] = Event(
          name: editedName,
          date: event.date,
          status: event.status,
        );
        _events.sort((a, b) => b.date.compareTo(a.date));
      });
      _saveEvents();
    }
  }

  void _deleteEvent(Event event) {
    setState(() {
      _events.remove(event);
    });
    _saveEvents();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // 统一使用全局顶部栏，避免各页面重复维护
            AppTopBar(),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatCards(),
                    _buildCalendar(),
                    _buildTodaySchedule(selectedDayEvents),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 78),
        child: GestureDetector(
          onTap: _punchCard,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 与「统计详情」按钮一致的实心背景色
              color: Color(0xFF333333),
            ),
            child: Icon(Icons.check, color: Colors.white, size: 28),
          ),
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
                '打卡',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 4),
//               Text(
//                 '查看排期，掌控每日事件',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF999999),
//                 ),
//               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final total = _getTotalEvents();
    final comparison = _getMonthComparison();
    final isUp = _isComparisonUp();
    final target = _focusedDay;

    return Container(
      margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE1E1E1)),
      ),
      child: Row(
        children: [
          // 左侧：事件统计，点击打开月份选择
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showMonthPicker,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF333333)),
                      SizedBox(width: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF333333).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${target.month}月',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '切换日期',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        total.toString(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      // 「次」与「切换日期」文字样式保持一致
                      Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 3),
                        child: Text(
                          '次',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        margin: EdgeInsets.only(bottom: 2),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isUp ? Color(0xFF2ED573) : Color(0xFFFF6B6B)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isUp ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 10,
                              color: isUp ? Color(0xFF2ED573) : Color(0xFFFF6B6B),
                            ),
                            SizedBox(width: 2),
                            Text(
                              '较上月 $comparison',
                              style: TextStyle(
                                fontSize: 10,
                                color: isUp ? Color(0xFF2ED573) : Color(0xFFFF6B6B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 右侧：统计详情入口（按钮样式）
          GestureDetector(
            onTap: _openStatistics,
            child: Container(
              margin: EdgeInsets.only(left: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // 背景与文字颜色对调：深色实心底 + 白色图标文字
                color: Color(0xFF333333),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '统计详情',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE1E1E1)),
      ),
      child: TableCalendar(
        locale: 'zh_CN',
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        headerVisible: false,
        daysOfWeekHeight: 40,
        // 星期标题只显示「一、二、三…」，不显示「周一、周二…」
        daysOfWeekStyle: DaysOfWeekStyle(
          dowTextFormatter: (date, locale) {
            const labels = ['一', '二', '三', '四', '五', '六', '日'];
            return labels[date.weekday - 1];
          },
        ),
        rowHeight: 48,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          // 滑动翻页时同步刷新上方统计（原本只赋值不重建）
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          // 关闭默认事件圆点（背景色与底部文字已表达有事件）
          markersMaxCount: 0,
          defaultTextStyle: TextStyle(
            color: Color(0xFF333333),
          ),
          weekendTextStyle: TextStyle(
            color: Color(0xFF333333),
          ),
        ),
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, date, focusedDay) => _buildCalendarDayCell(
            date,
            _getEventsForDay(date),
            isSelected: true,
          ),
          todayBuilder: (context, date, focusedDay) => _buildCalendarDayCell(
            date,
            _getEventsForDay(date),
            isToday: true,
          ),
          defaultBuilder: (context, date, focusedDay) => _buildCalendarDayCell(
            date,
            _getEventsForDay(date),
          ),
          outsideBuilder: (context, date, events) {
            return Container(
              margin: const EdgeInsets.all(2.0),
              alignment: Alignment.center,
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodaySchedule(List<Event> todayEvents) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '当日事件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                '共 ${todayEvents.length} 项',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF999999),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (todayEvents.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFE1E1E1)),
              ),
              child: Center(
                child: Text(
                  '暂无安排',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            )
          else
            ...todayEvents.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Icon(Icons.delete, color: Colors.white, size: 18),
      ),
      onDismissed: (direction) {
        _deleteEvent(event);
        showToast(context, '事件已删除');
      },
      child: GestureDetector(
        onTap: () => _editEvent(event),
        child: Container(
          margin: EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFFE1E1E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
