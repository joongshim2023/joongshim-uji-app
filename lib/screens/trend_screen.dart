import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/energy_service.dart';
import '../services/memo_service.dart';
import '../theme/app_strings.dart';

class TrendScreen extends StatefulWidget {
  final void Function(DateTime date)? onDateSelected;
  const TrendScreen({Key? key, this.onDateSelected}) : super(key: key);

  @override
  _TrendScreenState createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  int _viewMode = 0;

  DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _currentWeekStart;

  final AuthService _auth = AuthService();
  final EnergyService _energy = EnergyService();
  final MemoService _memoService = MemoService();

  // 메모 있는 날짜 Set (yyyy-MM-dd)
  Set<String> _memoDates = {};
  bool _isEditMode = false;
  Set<String> _selectedEditDates = {};


  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    int daysFromMonday = now.weekday - 1;
    _currentWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMonday));
    _loadMemoDates();
  }

  /// 현재 월의 메모 있는 날짜 목록 로드
  Future<void> _loadMemoDates() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final memos = await _memoService.getMemosInRange(uid, start, end);
    if (mounted) {
      setState(() {
        _memoDates = memos
            .where((m) => (m['content'] as String? ?? '').isNotEmpty)
            .map((m) => m['date'] as String)
            .toSet();
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
    _loadMemoDates();
  }

  void _changeWeek(int delta) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: delta * 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text("로그인이 필요합니다.", style: TextStyle(color: Colors.white)));
    }

    DateTime start = _viewMode == 0
        ? DateTime(_currentMonth.year, _currentMonth.month, 1)
        : _currentWeekStart;
    DateTime end = _viewMode == 0
        ? DateTime(_currentMonth.year, _currentMonth.month + 1, 0)
        : _currentWeekStart.add(const Duration(days: 6));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr(context, "유지 통계"),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite)),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.timelineBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ToggleButtons(
                      isSelected: [_viewMode == 0, _viewMode == 1],
                      onPressed: (index) => setState(() => _viewMode = index),
                      color: AppTheme.textGray,
                      selectedColor: AppTheme.deepNavy,
                      fillColor: AppTheme.mutedTeal,
                      borderRadius: BorderRadius.circular(20),
                      constraints:
                          const BoxConstraints(minWidth: 100, minHeight: 36),
                      children: [
                        Text(AppStrings.tr(context, "캘린더"),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(AppStrings.tr(context, "그래프"),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: _energy.getLogsStream(uid, start, end),
                builder: (context, snapshot) {
                  Map<String, int> efficiencyMap = {};
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      efficiencyMap[data['date']] =
                          (data['efficiencyPct'] ?? 0).toInt();
                    }
                  }
                  return _viewMode == 0
                      ? _buildCalendarView(efficiencyMap)
                      : _buildGraphView(efficiencyMap);
                }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String type) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Warning', style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: Text(
          'Delete ${_selectedEditDates.length} date(s) of ${type == 'memo' ? 'Memo' : 'Record'}?\nThis cannot be undone.',
          style: const TextStyle(color: AppTheme.textWhite, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        for (String dateKey in _selectedEditDates) {
          if (type == 'memo') {
            await _memoService.deleteMemo(uid, dateKey);
          } else {
            await _energy.deleteDailyLog(uid, dateKey);
          }
        }
        if (mounted) {
          setState(() {
            _isEditMode = false;
            _selectedEditDates.clear();
          });
          _loadMemoDates();
        }
      }
    }
  }

  Widget _buildCalendarView(Map<String, int> EFF_MAP) {
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = _currentMonth.weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite),
                  onPressed: _isEditMode ? null : () => _changeMonth(-1)),
              Text(DateFormat('yyyy.M').format(_currentMonth),
                  style: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppTheme.textWhite),
                  onPressed: _isEditMode ? null : () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Text(d,
                    style: const TextStyle(
                        color: AppTheme.textGray, fontSize: 12)))
                .toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                if (index < offset || index >= offset + daysInMonth) {
                  return const SizedBox();
                }
                int day = index - offset + 1;
                DateTime d =
                    DateTime(_currentMonth.year, _currentMonth.month, day);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                int? efficiency = EFF_MAP[dateKey];
                bool isToday = DateFormat('yyyyMMdd').format(d) ==
                    DateFormat('yyyyMMdd').format(DateTime.now());
                bool hasMemo = _memoDates.contains(dateKey);

                return GestureDetector(
                  onTap: () {
                    if (_isEditMode) {
                      setState(() {
                        if (_selectedEditDates.contains(dateKey)) {
                          _selectedEditDates.remove(dateKey);
                        } else {
                          _selectedEditDates.add(dateKey);
                        }
                      });
                    } else {
                      widget.onDateSelected?.call(d);
                    }
                  },
                  child: Container(
                  decoration: BoxDecoration(
                    color: hasMemo
                        ? AppTheme.mutedTeal.withOpacity(0.22)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: _isEditMode && _selectedEditDates.contains(dateKey)
                        ? Border.all(color: AppTheme.mutedTeal, width: 2.0)
                        : (isToday
                            ? Border.all(color: AppTheme.yellowAccent, width: 1.5)
                            : null),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isToday
                                      ? AppTheme.yellowAccent
                                      : AppTheme.textWhite)),
                          if (efficiency != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('$efficiency%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.activeGreen)),
                            ),
                        ],
                      ),
                      if (_isEditMode && _selectedEditDates.contains(dateKey))
                        const Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.check_circle,
                              color: AppTheme.mutedTeal, size: 14),
                        ),
                    ],
                  ),
                ),
                );
              },
            ),
          ),
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 편집 모드: 날짜 선택 안내 + 삭제 버튼 2개 위
                if (_isEditMode && _selectedEditDates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _confirmDelete('record'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            AppStrings.tr(context, '기록 삭제'),
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _confirmDelete('memo'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            AppStrings.tr(context, '메모 삭제'),
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 하단 로우: 삭제/취소 버튼 + 안내 문구
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditMode = !_isEditMode;
                          _selectedEditDates.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        _isEditMode ? AppStrings.tr(context, '취소') : AppStrings.tr(context, '삭제'),
                        style: TextStyle(
                          color: _isEditMode ? AppTheme.textGray : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _isEditMode
                            ? AppStrings.tr(context, '기록 또는 메모를 삭제할 날짜를 선택하세요')
                            : AppStrings.tr(context, '메모가 있는 날은 배경색이 다릅니다.\n날짜를 클릭하면 기록을 볼 수 있습니다.'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: _isEditMode ? AppTheme.mutedTeal : AppTheme.textGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphView(Map<String, int> EFF_MAP) {
    List<FlSpot> spots = [];
    List<String> xLabels = [];
    for (int i = 0; i < 7; i++) {
      DateTime d = _currentWeekStart.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(d);
      int eff = EFF_MAP[dateKey] ?? 0;
      spots.add(FlSpot(i.toDouble(), eff.toDouble()));
      xLabels.add(DateFormat('MM/dd').format(d));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon:
                      const Icon(Icons.chevron_left, color: AppTheme.textWhite),
                  onPressed: () => _changeWeek(-1)),
              Column(
                children: [
                  const Text("Weekly Trend",
                      style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.bold)),
                  Text(
                      '${DateFormat('MM.dd').format(_currentWeekStart)} ~ ${DateFormat('MM.dd').format(_currentWeekStart.add(const Duration(days: 6)))}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textGray)),
                ],
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: AppTheme.textWhite),
                  onPressed: () => _changeWeek(1)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 16.0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppTheme.timelineBg, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= xLabels.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(xLabels[idx],
                                style: const TextStyle(
                                    color: AppTheme.textGray, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%',
                              style: const TextStyle(
                                  color: AppTheme.textGray, fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.mutedTeal,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: AppTheme.deepNavy,
                                strokeWidth: 2,
                                strokeColor: AppTheme.mutedTeal,
                              )),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.mutedTeal.withOpacity(0.3),
                            AppTheme.mutedTeal.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
