import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/event_model.dart';
import '../services/local_storage.dart';
import '../utils/toast_util.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

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
                        color: Color(0xFF1A1A2E),
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
                          icon: Icon(Icons.chevron_left, color: Color(0xFF4A7CF7)),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selectedYear 年',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A7CF7),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedYear++;
                            });
                          },
                          icon: Icon(Icons.chevron_right, color: Color(0xFF4A7CF7)),
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
                              color: isSelected ? Color(0xFF4A7CF7) : Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$month月',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : Color(0xFF1A1A2E),
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
                              style: TextStyle(color: Color(0xFF9A9AB0)),
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
                              style: TextStyle(color: Color(0xFF4A7CF7)),
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
                              backgroundColor: Color(0xFF4A7CF7),
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
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
    if (last == 0) return current > 0 ? '+$current' : '0';
    final diff = current - last;
    final percent = ((diff / last) * 100).round();
    if (diff > 0) return '+$percent%';
    if (diff < 0) return '$percent%';
    return '0%';
  }

  bool _isComparisonUp() {
    final current = _getTotalEvents();
    final last = _getLastMonthEvents();
    return current >= last;
  }

  void _punchCard() {
    final punchDate = _selectedDay ?? DateTime.now();
    final newEvent = Event(
      name: '新事件',
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
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入事件名称',
                  hintStyle: TextStyle(color: Color(0xFF9A9AB0)),
                  filled: true,
                  fillColor: Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF4A7CF7), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
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
                        color: Color(0xFF9A9AB0),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A7CF7),
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
      backgroundColor: Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
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
        padding: EdgeInsets.only(bottom: 70),
        child: GestureDetector(
          onTap: _punchCard,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A7CF7).withValues(alpha: 0.8),
                  Color(0xFF2E5CF7).withValues(alpha: 0.9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4A7CF7).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 28),
                ),
              ),
            ),
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
                '一键打卡',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '查看排期，掌控每日事件',
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

  Widget _buildStatCards() {
    final total = _getTotalEvents();
    final comparison = _getMonthComparison();
    final isUp = _isComparisonUp();
    final now = _currentTime;
    final target = _focusedDay;

    return Container(
      margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF4A7CF7)),
                        SizedBox(width: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${target.month}月',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A7CF7),
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '事件',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9AB0),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          total.toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
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
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _showMonthPicker,
                child: Container(
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A7CF7),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_focusedDay.year}/${_focusedDay.month.toString().padLeft(2, '0')}/${_focusedDay.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9AB0),
                        ),
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

  Widget _buildCalendar() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'zh_CN',
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        headerVisible: false,
        daysOfWeekHeight: 40,
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
          _focusedDay = focusedDay;
        },
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: Color(0xFF4A7CF7),
            fontWeight: FontWeight.bold,
          ),
          defaultTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
          ),
          weekendTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
          ),
        ),
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, date, events) => Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(0xFF4A7CF7),
              shape: BoxShape.circle,
            ),
            child: Text(
              date.day.toString(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          todayBuilder: (context, date, events) => Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              date.day.toString(),
              style: TextStyle(
                color: Color(0xFF4A7CF7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF9F43),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
          defaultBuilder: (context, date, events) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                ),
              ),
            );
          },
          outsideBuilder: (context, date, events) {
            return Container(
              margin: const EdgeInsets.all(4.0),
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
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '共 ${todayEvents.length} 项',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9A9AB0),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '暂无安排',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9AB0),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
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
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A9AB0),
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
