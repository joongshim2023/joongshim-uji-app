import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/energy_service.dart';

class TrendScreen extends StatefulWidget {
  const TrendScreen({Key? key}) : super(key: key);

  @override
  _TrendScreenState createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  int _viewMode = 0;
  
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _currentWeekStart;

  final AuthService _auth = AuthService();
  final EnergyService _energy = EnergyService();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    int daysFromMonday = now.weekday - 1;
    _currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
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
      return const Center(child: Text("로그인이 필요합니다.", style: TextStyle(color: Colors.white)));
    }

    DateTime start = _viewMode == 0 ? DateTime(_currentMonth.year, _currentMonth.month, 1) : _currentWeekStart;
    DateTime end = _viewMode == 0 ? DateTime(_currentMonth.year, _currentMonth.month + 1, 0) : _currentWeekStart.add(const Duration(days: 6));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "에너지감각 유지 통계 분석", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textWhite)
                ),
                const SizedBox(height: 8),
                const Text(
                  "기간별 에너지감각 유지 비중 추이를 확인하세요.",
                  style: TextStyle(color: AppTheme.textGray, fontSize: 14),
                ),
                const SizedBox(height: 24),
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
                      constraints: const BoxConstraints(minWidth: 100, minHeight: 36),
                      children: const [
                        Text("캘린더", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("그래프", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    efficiencyMap[data['date']] = (data['efficiencyPct'] ?? 0).toInt();
                  }
                }
                return _viewMode == 0 ? _buildCalendarView(efficiencyMap) : _buildGraphView(efficiencyMap);
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(Map<String, int> EFF_MAP) {
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = _currentMonth.weekday; 
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite), onPressed: () => _changeMonth(-1)),
              Text(DateFormat('yyyy년 MM월').format(_currentMonth), style: const TextStyle(fontSize: 18, color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.chevron_right, color: AppTheme.textWhite), onPressed: () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['일', '월', '화', '수', '목', '금', '토'].map((d) => 
              Text(d, style: const TextStyle(color: AppTheme.textGray, fontSize: 12))
            ).toList(),
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
                DateTime d = DateTime(_currentMonth.year, _currentMonth.month, day);
                String dateKey = DateFormat('yyyy-MM-dd').format(d);
                int? efficiency = EFF_MAP[dateKey];
                bool isToday = DateFormat('yyyyMMdd').format(d) == DateFormat('yyyyMMdd').format(DateTime.now());

                return Container(
                  decoration: BoxDecoration(
                    color: efficiency != null ? AppTheme.mutedTeal.withOpacity(0.2) : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: AppTheme.yellowAccent, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontSize: 11, color: isToday ? AppTheme.yellowAccent : AppTheme.textWhite)),
                      if (efficiency != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('$efficiency%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.activeGreen)),
                        ),
                    ],
                  ),
                );
              },
            ),
          )
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
              IconButton(icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite), onPressed: () => _changeWeek(-1)),
              Column(
                children: [
                   const Text("주간 동향", style: TextStyle(fontSize: 16, color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                  Text(
                    '${DateFormat('MM.dd').format(_currentWeekStart)} ~ ${DateFormat('MM.dd').format(_currentWeekStart.add(const Duration(days: 6)))}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textGray)
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.chevron_right, color: AppTheme.textWhite), onPressed: () => _changeWeek(1)),
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
                    getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.timelineBg, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(xLabels[idx], style: const TextStyle(color: AppTheme.textGray, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%', style: const TextStyle(color: AppTheme.textGray, fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 6,
                  minY: 0, maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.mutedTeal,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4, color: AppTheme.deepNavy, strokeWidth: 2, strokeColor: AppTheme.mutedTeal,
                        )
                      ),
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
