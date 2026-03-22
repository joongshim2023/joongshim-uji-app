import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/energy_clock_picker.dart';
import '../widgets/timeline_row.dart';
import '../services/auth_service.dart';
import '../services/energy_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _now = DateTime.now();
  late DateTime _selectedDate;
  int _selectedHour = DateTime.now().hour;
  Timer? _timer;

  final AuthService _authService = AuthService();
  final EnergyService _energy = EnergyService();

  int _localStartHour = 7;
  int _localEndHour = 24;
  String _inputType = 'bar';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(_now.year, _now.month, _now.day);
    _timer = Timer.periodic(const Duration(minutes: 1), (time) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadDefaultSettings();
  }

  Future<void> _loadDefaultSettings() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      var data = await _energy.getUserSettings(uid);
      if (mounted) {
        setState(() {
          // 일일 설정이 로드되기 전에 먼저 전역 기본값을 세팅합니다
          if (_localStartHour == 7 && _localEndHour == 24) {
             _localStartHour = data['startHour'] ?? 7;
             _localEndHour = data['endHour'] ?? 24;
          }
          _inputType = data['inputType'] ?? 'bar';
        });
      }
      NotificationService().rescheduleAlarms(
        startHour: data['startHour'] ?? 7,
        endHour: data['endHour'] ?? 24,
        intervalMinutes: data['alarmInterval'] ?? 60,
        alarmOn: data['alarmOn'] ?? false,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String? get uid => _authService.currentUser?.uid;

  Timer? _debounce;
  Map<String, int> _optimisticRecords = {};
  int? _pendingHour;
  int? _pendingMinutes;

  void _flushPending() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      if (_pendingHour != null && _pendingMinutes != null && uid != null) {
        final h = _pendingHour!;
        final m = _pendingMinutes!;
        _energy.updateEnergyLog(
          userId: uid!,
          date: _selectedDate,
          hour: h,
          minutes: m,
          startHour: _localStartHour,
          endHour: _localEndHour,
        ).then((_) {
          if (mounted) {
            setState(() => _optimisticRecords.remove(h.toString().padLeft(2, '0')));
          }
        });
      }
      _pendingHour = null;
      _pendingMinutes = null;
    }
  }

  void _updateEnergy(int minutes) {
    if (uid == null) return;
    
    if (_pendingHour != null && _pendingHour != _selectedHour) {
      _flushPending();
    }

    setState(() {
      _optimisticRecords[_selectedHour.toString().padLeft(2, '0')] = minutes;
    });

    _pendingHour = _selectedHour;
    _pendingMinutes = minutes;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _flushPending();
    });
  }

  void _updateSettings(int start, int end) {
    if (uid == null) return;
    setState(() {
      _localStartHour = start;
      _localEndHour = end;
    });
    _energy.updateEnergyLog(
      userId: uid!,
      date: _selectedDate,
      hour: -1,
      minutes: 0,
      startHour: start,
      endHour: end,
    );
  }

  void _changeDate(int delta) {
    _flushPending();
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      if (DateFormat('yyyyMMdd').format(_selectedDate) == DateFormat('yyyyMMdd').format(_now)) {
        _selectedHour = _now.hour;
      } else {
        _selectedHour = 12;
      }
    });
  }

  void _showTimeSettings() {
    showDialog(
      context: context,
      builder: (context) {
        int tempStart = _localStartHour;
        int tempEnd = _localEndHour;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: const Text('활동 시간 설정', style: TextStyle(color: AppTheme.textWhite)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${DateFormat('yyyy년 MM월 dd일').format(_selectedDate)}의 활동 시간', style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('기상 시간', style: TextStyle(color: AppTheme.textWhite)),
                      DropdownButton<int>(
                        value: tempStart,
                        dropdownColor: AppTheme.timelineBg,
                        style: const TextStyle(color: AppTheme.activeGreen),
                        items: List.generate(24, (i) => i).map((h) => DropdownMenuItem(value: h, child: Text('$h시'))).toList(),
                        onChanged: (val) {
                          if (val != null && val < tempEnd) setDialogState(() => tempStart = val);
                        },
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('취침 시간', style: TextStyle(color: AppTheme.textWhite)),
                      DropdownButton<int>(
                        value: tempEnd,
                        dropdownColor: AppTheme.timelineBg,
                        style: const TextStyle(color: AppTheme.activeGreen),
                        items: List.generate(25, (i) => i).map((h) => DropdownMenuItem(value: h, child: Text('$h시'))).toList(),
                        onChanged: (val) {
                          if (val != null && val > tempStart) setDialogState(() => tempEnd = val);
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: AppTheme.textGray))),
                TextButton(
                  onPressed: () {
                    _updateSettings(tempStart, tempEnd);
                    Navigator.pop(context);
                  }, 
                  child: const Text('저장', style: TextStyle(color: AppTheme.mutedTeal))
                ),
              ],
            );
          }
        );
      }
    );
  }

  bool _isActive(int h) {
    int end = _localEndHour == 24 ? 23 : _localEndHour;
    return h >= _localStartHour && h <= end;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text("로그인이 필요합니다.", style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _energy.getDailyLogStream(uid!, _dateKey),
      builder: (context, snapshot) {
        Map<String, dynamic> recordsMap = {};
        int totalActive = 0;
        int pct = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          recordsMap = data['records'] ?? {};
          
          // 동기화 시 로컬 값 업데이트 (비동기 화면 렌더링 중 setState 제외)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (data['startHour'] != null && _localStartHour != data['startHour']) setState(() => _localStartHour = data['startHour']);
              if (data['endHour'] != null && _localEndHour != data['endHour']) setState(() => _localEndHour = data['endHour']);
            }
          });
        }
        
        // Calculate realtime metrics including optimistic updates
        Map<String, dynamic> mergedRecords = Map.from(recordsMap);
        _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);
        
        int end = _localEndHour == 24 ? 23 : _localEndHour;
        int goalMins = (end - _localStartHour + 1) * 60;
        
        mergedRecords.forEach((key, val) {
          int h = int.parse(key);
          if (h >= _localStartHour && h <= end) {
            totalActive += (val as num).toInt();
          }
        });
        pct = goalMins > 0 ? (totalActive / goalMins * 100).toInt() : 0;

        bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) == DateFormat('yyyyMMdd').format(_now);
        int currentHour = isToday ? _now.hour : -1;
        int currentMin = isToday ? _now.minute : -1;

        return SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDateSelector(),
              _buildSummaryBadge(totalActive, pct),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO: 시계형 복원 시 아래 주석 해제하고 바 타입 주석 처리
                    // _inputType == 'clock' ? _buildClockPickerPanel(recordsMap) : _buildClockPanel(recordsMap)
                    Expanded(
                      flex: 4, 
                      child: _buildClockPanel(recordsMap),
                    ),
                    Expanded(flex: 8, child: _buildTimeline(recordsMap, currentHour, currentMin)),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt, color: AppTheme.mutedTeal),
          const SizedBox(width: 8),
          const Text('중심 유지 App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textGray),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('로그아웃', style: TextStyle(color: AppTheme.textWhite)),
                  content: const Text('로그아웃 하시겠습니까?', style: TextStyle(color: AppTheme.textGray)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소', style: TextStyle(color: AppTheme.textGray)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('로그아웃', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await _authService.signOut();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그아웃 오류: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) == DateFormat('yyyyMMdd').format(_now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite),
            onPressed: () => _changeDate(-1),
          ),
          InkWell(
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: _now.subtract(const Duration(days: 365)),
                lastDate: _now,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppTheme.mutedTeal, onPrimary: AppTheme.deepNavy, surface: AppTheme.bgCard, onSurface: AppTheme.textWhite),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Column(
              children: [
                Text(DateFormat('yyyy. MM. dd').format(_selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
                if (isToday) const Text('오늘', style: TextStyle(fontSize: 12, color: AppTheme.activeGreen)),
                if (!isToday) const Text('과거 기록', style: TextStyle(fontSize: 12, color: AppTheme.softIndigo)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.chevron_right, color: isToday ? AppTheme.textGray.withOpacity(0.3) : AppTheme.textWhite), onPressed: isToday ? null : () => _changeDate(1)),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(int totalMins, int pct) {
    int h = totalMins ~/ 60;
    int m = totalMins % 60;
    return GestureDetector(
      onTap: _showTimeSettings,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('${h}h ${m}m', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
                    const SizedBox(height: 4),
                    const Text('총 유지시간', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
                  ],
                ),
                Container(width: 1, height: 40, color: AppTheme.timelineBg),
                Column(
                  children: [
                    Text('$pct%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.activeGreen)),
                    const SizedBox(height: 4),
                    const Text('유지 비중', style: TextStyle(color: AppTheme.activeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.timelineBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppTheme.softIndigo),
                  const SizedBox(width: 4),
                  Text('활동시간 설정: $_localStartHour시 ~ $_localEndHour시', style: const TextStyle(fontSize: 12, color: AppTheme.textWhite)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: AppTheme.textGray),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockPanel(Map<String, dynamic> records) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    int currentRecord = ((mergedRecords[_selectedHour.toString().padLeft(2, '0')] ?? 0) as num).toInt();
    int pct = (currentRecord / 60 * 100).toInt();
    bool isActiveWindow = _isActive(_selectedHour);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, color: AppTheme.mutedTeal, size: 20), 
                onPressed: _selectedHour > 0 ? () { _flushPending(); setState(() => _selectedHour--); } : null
              ),
              Column(
                children: [
                  Text(_selectedHour.toString().padLeft(2, '0')+':00', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textWhite, fontFamily: 'monospace')),
                  const Text('선택됨', style: TextStyle(fontSize: 9, color: AppTheme.textGray)),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, color: AppTheme.mutedTeal, size: 20), 
                onPressed: _selectedHour < 23 ? () { _flushPending(); setState(() => _selectedHour++); } : null
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$pct%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isActiveWindow ? AppTheme.activeGreen : AppTheme.textGray.withOpacity(0.5))),
              const SizedBox(width: 4),
              Text('$currentRecord분', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActiveWindow ? AppTheme.textWhite : AppTheme.textGray.withOpacity(0.5))),
            ],
          ),
          
          if (!isActiveWindow)
            const Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text('수면 시간', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
            )
          else
            const SizedBox(height: 8),
            
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableHeight = constraints.maxHeight;
                double segmentHeight = availableHeight / 13;
                double dynamicFontSize = (segmentHeight * 0.45).clamp(8.0, 16.0);
                
                return GestureDetector(
                  onVerticalDragUpdate: isActiveWindow ? (details) {
                    double dy = details.localPosition.dy;
                    int index = (dy / availableHeight * 13).floor().clamp(0, 12);
                    _updateEnergy(index * 5);
                  } : null,
                  onVerticalDragDown: isActiveWindow ? (details) {
                    double dy = details.localPosition.dy;
                    int index = (dy / availableHeight * 13).floor().clamp(0, 12);
                    _updateEnergy(index * 5);
                  } : null,
                  child: Column(
                    children: List.generate(13, (index) {
                      int stepValue = index * 5;
                      bool isFilled = currentRecord >= stepValue;
                      bool isSelected = currentRecord == stepValue;
                      
                      Color bgColor = AppTheme.timelineBg;
                      Color textColor = AppTheme.textGray;
                      Color borderColor = Colors.transparent;
                      
                      if (isActiveWindow) {
                        if (isFilled) {
                          bgColor = AppTheme.activeGreen.withOpacity(0.9);
                          textColor = AppTheme.deepNavy;
                        }
                        if (isSelected) {
                          borderColor = AppTheme.textWhite;
                        }
                      } else {
                        if (isFilled) {
                          bgColor = AppTheme.textGray.withOpacity(0.3);
                          textColor = AppTheme.textWhite.withOpacity(0.5);
                        } else {
                          textColor = AppTheme.textGray.withOpacity(0.3);
                        }
                        if (isSelected) {
                          borderColor = AppTheme.textGray.withOpacity(0.5);
                        }
                      }
                      
                      return Expanded(
                        child: FractionallySizedBox(
                          widthFactor: 0.8,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                            ),
                            child: Center(
                              child: Text(
                                '$stepValue',
                                style: TextStyle(
                                  fontSize: dynamicFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _buildClockPickerPanel(Map<String, dynamic> records) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    int currentRecord = ((mergedRecords[_selectedHour.toString().padLeft(2, '0')] ?? 0) as num).toInt();
    bool isActiveWindow = _isActive(_selectedHour);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: AppTheme.mutedTeal), onPressed: _selectedHour > 0 ? () { _flushPending(); setState(() => _selectedHour--); } : null),
              Column(
                children: [
                  Text(_selectedHour.toString().padLeft(2, '0')+':00', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite, fontFamily: 'monospace')),
                  const Text('선택됨', style: TextStyle(fontSize: 10, color: AppTheme.textGray)),
                ],
              ),
              IconButton(icon: const Icon(Icons.chevron_right, color: AppTheme.mutedTeal), onPressed: _selectedHour < 23 ? () { _flushPending(); setState(() => _selectedHour++); } : null),
            ],
          ),
          const SizedBox(height: 12),
          if (!isActiveWindow)
            const Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text('수면 시간', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
            )
          else
            const SizedBox(height: 24),
          Expanded(
            child: EnergyClockPicker(
              minutes: currentRecord,
              isActive: isActiveWindow,
              onChanged: (val) {
                if (isActiveWindow) _updateEnergy(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> records, int currentHour, int currentMin) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: ListView.builder(
        itemCount: 24,
        itemBuilder: (context, index) {
          int record = ((mergedRecords[index.toString().padLeft(2, '0')] ?? 0) as num).toInt();
          return TimelineRow(
            hour: index,
            minutes: record,
            isSelected: _selectedHour == index,
            isCurrent: currentHour == index,
            currentMinute: currentMin,
            isActiveWindow: _isActive(index),
            onTap: () {
               _flushPending();
               setState(() => _selectedHour = index);
            },
          );
        },
      ),
    );
  }
}
