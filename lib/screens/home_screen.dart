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
import '../services/memo_service.dart';
import '../services/notification_service.dart';
import '../widgets/marquee_text.dart';
import 'memo_screen.dart';
import '../theme/app_strings.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

class HomeScreen extends StatefulWidget {
  final DateTime? initialDate;
  final void Function(DateTime date)? onOpenMemo;

  const HomeScreen({Key? key, this.initialDate, this.onOpenMemo}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  bool _isSaveError = false;
  late DateTime _selectedDate;
  // null = 미선택 (과거 날짜). 오늘은 현재 시간 초기값.
  int? _selectedHour;
  Timer? _timer;

  final AuthService _authService = AuthService();
  final EnergyService _energy = EnergyService();
  final MemoService _memoService = MemoService();
  bool _hasMemoToday = false;

  int _localStartHour = 7;
  int _localEndHour = 24;

  // global 기본값 (settings/default에서 로드, 날짜별 로그 없을 때 사용)
  int _defaultStartHour = 7;
  int _defaultEndHour = 24;

  // 다음날(자정 초과) 구간에서 선택된 시간인지 구분
  bool _isNextDaySelected = false;

  // 타임라인 스크롤 컨트롤러
  final ScrollController _timelineScrollController = ScrollController();
  bool _hasScrolledToCurrentTime = false;

  String? _dailyPhrase;

  Future<void> _loadDailyPhrase() async {
    try {
      final uSeed = uid?.hashCode ?? 0;
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('sentence').get();
      if (doc.exists) {
        final data = doc.data()!;
        List<dynamic> phrases = [];
        if (data['phrase'] is List) {
          phrases = data['phrase'] as List;
        } else if (data['phrases'] is List) {
          phrases = data['phrases'] as List;
        } else if (data['good_phrase'] != null) {
          phrases = [data['good_phrase']];
        }

        if (phrases.isNotEmpty) {
          final dateSeed = _now.year * 10000 + _now.month * 100 + _now.day;
          final index = (dateSeed + uSeed).abs() % phrases.length;
          if (mounted) {
            setState(() {
              _dailyPhrase = phrases[index].toString();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading phrase: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDailyPhrase();
    // initialDate: 캘린더에서 날짜 지정 이동 지원
    _selectedDate = widget.initialDate != null
        ? DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day)
        : DateTime(_now.year, _now.month, _now.day);
    // 오늘이면 현재 시간 선택, 과거이면 미선택
    _selectedHour = _isSelectedDateToday ? _now.hour : null;
    _timer = Timer.periodic(const Duration(minutes: 1), (time) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadDefaultSettings();
    _checkMemo();
  }

  Future<void> _loadDefaultSettings() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      var data = await _energy.getUserSettings(uid);
      if (mounted) {
        setState(() {
          _defaultStartHour = data['startHour'] ?? 7;
          _defaultEndHour = data['endHour'] ?? 24;
          // 첫 로드 시 local도 default로 초기화 (StreamBuilder가 날짜별로 덮어씀)
          _localStartHour = _defaultStartHour;
          _localEndHour = _defaultEndHour;
        });
        _scrollToCurrentTime();
      }
      NotificationService().rescheduleAlarms(
        startHour: data['startHour'] ?? 7,
        endHour: data['endHour'] ?? 24,
        intervalMinutes: data['alarmInterval'] ?? 60,
        alarmOn: data['alarmOn'] ?? true,
      );
    }
  }

  Future<void> _checkMemo() async {
    final u = uid;
    if (u == null) return;
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final data = await _memoService.getMemoOnce(u, dateKey);
    if (mounted) {
      setState(() {
        _hasMemoToday = data != null && (data['content'] as String? ?? '').isNotEmpty;
      });
    }
  }

  /// 현재 시간(또는 선택된 시간)이 타임라인 중앙에 오도록 스크롤
  void _scrollToCurrentTime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timelineScrollController.hasClients) return;

      bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) ==
          DateFormat('yyyyMMdd').format(_now);
      int targetHour = isToday ? _now.hour : (_selectedHour ?? _now.hour);

      // 각 TimelineRow의 대략적인 높이 (vertical margin 2*2 + padding 8*2 + content ≈ 46px)
      const double rowHeight = 46.0;
      final double viewportHeight =
          _timelineScrollController.position.viewportDimension;

      // 타임라인 아이템 총 수 계산 (자정 초과 지원)
      int totalRows = _timelineRowCount;

      // 목표 행 인덱스 (0-based)
      int targetIndex = targetHour; // 0~23 내에서의 위치
      double scrollOffset =
          (targetIndex * rowHeight) - (viewportHeight / 2) + (rowHeight / 2);
      scrollOffset = scrollOffset.clamp(
        0.0,
        math.max(0, totalRows * rowHeight - viewportHeight),
      );

      _timelineScrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 자정 초과 여부 (endHour < startHour OR endHour >= 24)
  bool get _isOvernightMode =>
      _localEndHour < _localStartHour || _localEndHour >= 24;

  /// 실제 취침 시간 (다음날 인코딩 24+h → h 로 변환)
  int get _normalizedEndHour =>
      _localEndHour >= 24 ? _localEndHour - 24 : _localEndHour;

  /// 타임라인에 표시할 총 행 수 (자정 초과시 0~normalizedEndHour 행 추가)
  int get _timelineRowCount {
    if (_isOvernightMode) {
      return 24 + _normalizedEndHour + 1;
    }
    return 24;
  }

  bool _isFutureTime(int hour, bool isNextDay) {
    bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) ==
        DateFormat('yyyyMMdd').format(_now);
    if (!isToday) return false;
    if (isNextDay) return true;
    return hour > _now.hour;
  }

  // 선택된 시간이 활동 시간인지 (다음날 구간 고려)
  bool get _isSelectedHourActive {
    final h = _selectedHour;
    if (h == null) return false;
    if (_isFutureTime(h, _isNextDaySelected)) return false;
    if (_isNextDaySelected) return true; // 다음날 구간은 항상 활성
    if (_isOvernightMode) return h >= _localStartHour;
    int end = _localEndHour == 24 ? 23 : _localEndHour;
    return h >= _localStartHour && h <= end;
  }

  bool _isActive(int hour) {
    if (_isOvernightMode) {
      return hour >= _localStartHour || hour < _normalizedEndHour;
    } else {
      int end = _localEndHour == 24 ? 23 : _localEndHour;
      return hour >= _localStartHour && hour <= end;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPending();
    _timer?.cancel();
    _timelineScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _flushPending();
    }
    // 이슈2(알람 한꺼번에), 이슈3(앱 열면 알람) 해결:
    // 앱이 포그라운드로 복귀할 때 쌓인 알림 제거 + 신선한 알람 재등록
    if (state == AppLifecycleState.resumed) {
      NotificationService().onAppForegrounded();
      _checkMemo(); // 메모 상태도 갱신
    }
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
    }
    
    if (_pendingHour != null && _pendingMinutes != null && uid != null) {
      final h = _pendingHour!;
      final m = _pendingMinutes!;
      _energy
          .updateEnergyLog(
        userId: uid!,
        date: _selectedDate,
        hour: h,
        minutes: m,
        startHour: _localStartHour,
        endHour: _localEndHour,
      )
          .then((_) {
        if (mounted && _isSaveError) {
          setState(() => _isSaveError = false);
        }
        // Do not remove optimistic record here to prevent flashing.
        // The stream will eventually overwrite the state properly.
      }).catchError((_) {
        if (mounted && !_isSaveError) {
          setState(() => _isSaveError = true);
        }
      });
    }
    _pendingHour = null;
    _pendingMinutes = null;
  }

  void _updateEnergy(int minutes) {
    if (uid == null || _selectedHour == null) return;

    if (_pendingHour != null && _pendingHour != _selectedHour) {
      _flushPending();
    }

    setState(() {
      _optimisticRecords[_selectedHour!.toString().padLeft(2, '0')] = minutes;
      _isSaveError = false;
    });

    _pendingHour = _selectedHour;
    _pendingMinutes = minutes;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
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

  /// 오늘 여부 getter
  bool get _isSelectedDateToday =>
      DateFormat('yyyyMMdd').format(_selectedDate) ==
          DateFormat('yyyyMMdd').format(_now);

  void _changeDate(int delta) {
    _flushPending();
    setState(() {
      _optimisticRecords.clear();
      _selectedDate = _selectedDate.add(Duration(days: delta));
      // 오늘 → 현재 시간, 과거 → 미선택(null)
      _selectedHour = _isSelectedDateToday ? _now.hour : null;
      _isNextDaySelected = false;
      _hasScrolledToCurrentTime = false;
    });
    _scrollToCurrentTime();
    _checkMemo();
  }

  Future<void> _showTimeSettings() async {
    final u = uid;
    if (u == null) return;

    // 인접 날짜 제약 로드
    int minStartHour = 0; // 기상시간 최솟값
    int maxEndHour = _defaultStartHour; // 취침시간 최댓값 (다음날 기상시간, 기본은 default)

    // 전날 취침시간 → 기상시간 하한
    final prevData = await _energy.getDailyLogOnce(
        u, _selectedDate.subtract(const Duration(days: 1)));
    if (prevData != null) {
      final int prevEnd = prevData['endHour'] ?? 24;
      final int prevStart = prevData['startHour'] ?? 7;
      if (prevEnd < prevStart) {
        minStartHour = prevEnd;
      }
    }

    // 다음날 기상시간 → 취침시간 자정 초과 상한
    final nextData = await _energy.getDailyLogOnce(
        u, _selectedDate.add(const Duration(days: 1)));
    if (nextData != null) {
      maxEndHour = (nextData['startHour'] as int?) ?? _defaultStartHour;
    }

    if (!mounted) return;

    // [버그수정] tempEnd 초기값 계산
    // _localEndHour가 raw overnight 형식(< startHour)이면 피커용 24+h 인코딩으로 변환
    // 예: 취침 다음날 2시 → DB에 2로 저장 → 피커에서는 26(24+2)으로 표현
    int initialTempEnd = _localEndHour;
    if (initialTempEnd < _localStartHour && initialTempEnd >= 0) {
      // raw overnight 형식 → 24+h 인코딩으로 변환
      initialTempEnd = 24 + initialTempEnd;
    }
    bool initialEndValid =
        (initialTempEnd >= _localStartHour && initialTempEnd <= 24) ||
        (initialTempEnd >= 24 && initialTempEnd <= 24 + maxEndHour);
    if (!initialEndValid) initialTempEnd = _localStartHour;

    showDialog(
      context: context,
      builder: (context) {
        int tempStart = _localStartHour.clamp(minStartHour, 23);
        int tempEnd = initialTempEnd;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isOvernight = tempEnd < tempStart || tempEnd >= 24;
            int displayEnd = tempEnd >= 24 ? tempEnd - 24 : tempEnd;

            // 취침시간 레이블 헬퍼
            String endLabel(int h) {
              final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
              if (h == 24) return lang == 'en' ? '24:00 (midnight)' : '24:00(자정)';
              if (h > 24) return lang == 'en' ? '${h - 24}:00 (next)' : '${h - 24}:00(다음날)';
              return lang == 'en' ? '$h:00' : '$h:00';
            }

            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: Text(AppStrings.tr(context, '활동 시간 설정'),
                  style: const TextStyle(color: AppTheme.textWhite)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      DateFormat('yyyy.MM.dd').format(_selectedDate),
                      style: const TextStyle(
                          color: AppTheme.textGray, fontSize: 16)),
                  const SizedBox(height: 20),
                  // 기상 시간: minStartHour ~ tempEnd(실제값) 직전까지
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.tr(context, '기상 시간'),
                          style: const TextStyle(color: AppTheme.textWhite)),
                      DropdownButton<int>(
                        value: tempStart,
                        dropdownColor: AppTheme.timelineBg,
                        style: const TextStyle(color: AppTheme.activeGreen),
                        items: List.generate(24, (i) => i)
                            .where((h) => h >= minStartHour)
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text('$h:00'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              tempStart = val;
                              // 기상시간 변경 시 취침시간이 기상시간보다 작으면 보정
                              if (tempEnd < tempStart) tempEnd = tempStart;
                            });
                          }
                        },
                      )
                    ],
                  ),
                  // 취침 시간: tempStart시 ~ 24시(자정) + 1시(다음날)~maxEndHour시(다음날)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.tr(context, '취침 시간'),
                          style: const TextStyle(color: AppTheme.textWhite)),
                      DropdownButton<int>(
                        value: tempEnd,
                        dropdownColor: AppTheme.timelineBg,
                        style: const TextStyle(color: AppTheme.activeGreen),
                        items: [
                          // 같은날: tempStart ~ 24
                          for (int h = tempStart; h <= 24; h++)
                            DropdownMenuItem(
                              value: h,
                              child: Text(endLabel(h)),
                            ),
                          // 다음날: 1시 ~ maxEndHour시 (0시=24시=자정이므로 skip)
                          for (int h = 1; h <= maxEndHour; h++)
                            DropdownMenuItem(
                              value: 24 + h,
                              child: Text(endLabel(24 + h)),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tempEnd = val);
                        },
                      )
                    ],
                  ),
                  // 안내 메시지
                  if (minStartHour > 0)
                    _constraintHint('${AppStrings.tr(context, '기상 시간은 이전 취침 시간 이후여야 합니다.')} ($minStartHour:00).'),
                  _constraintHint('${AppStrings.tr(context, '취침 시간은 다음날 오전')} ${maxEndHour}${AppStrings.tr(context, '시까지 설정 가능합니다.')}'),
                  if (isOvernight)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.softIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppTheme.softIndigo),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${AppStrings.tr(context, '다음날 오전')} ${displayEnd}${AppStrings.tr(context, '시로 설정')}',
                                style: const TextStyle(
                                    color: AppTheme.softIndigo, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppStrings.tr(context, '취소'),
                        style: const TextStyle(color: AppTheme.textGray))),
                TextButton(
                  onPressed: () {
                    _updateSettings(tempStart, tempEnd);
                    Navigator.pop(context);
                  },
                  child: Text(AppStrings.tr(context, '저장'),
                      style: const TextStyle(color: AppTheme.mutedTeal)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 제약사항 안내 위젯
  Widget _constraintHint(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
                child: Text(message,
                    style:
                        const TextStyle(color: Colors.orange, fontSize: 11))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(
          child: Text("로그인이 필요합니다.", style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: _energy.getDailyLogStream(uid!, _dateKey),
        builder: (context, snapshot) {
          Map<String, dynamic> recordsMap = {};

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            recordsMap = data['records'] ?? {};

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                bool changed = false;
                // 해당 날짜에 저장된 기상/취침시간이 있으면 그것을 사용
                if (data['startHour'] != null &&
                    _localStartHour != data['startHour']) {
                  _localStartHour = data['startHour'];
                  changed = true;
                }
                if (data['endHour'] != null &&
                    _localEndHour != data['endHour']) {
                  _localEndHour = data['endHour'];
                  changed = true;
                }
                if (changed) setState(() {});
                if (!_hasScrolledToCurrentTime) {
                  _hasScrolledToCurrentTime = true;
                  _scrollToCurrentTime();
                }
              }
            });
          } else {
            // 해당 날짜에 데이터(기상/취침 포함)가 없으면 → default 값으로 리셋
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                bool changed = _localStartHour != _defaultStartHour ||
                    _localEndHour != _defaultEndHour;
                if (changed) {
                  setState(() {
                    _localStartHour = _defaultStartHour;
                    _localEndHour = _defaultEndHour;
                  });
                }
                if (!_hasScrolledToCurrentTime) {
                  _hasScrolledToCurrentTime = true;
                  _scrollToCurrentTime();
                }
              }
            });
          }

          // 자정 초과 여부
          bool isOvernight = _isOvernightMode;

          // 유지 비중 계산 (자정 초과 포함)
          Map<String, dynamic> mergedRecords = Map.from(recordsMap);
          _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

          // 총 목표 시간 계산
          int totalHours;
          if (isOvernight) {
            totalHours = (24 - _localStartHour) + _normalizedEndHour;
          } else {
            int end = _localEndHour == 24 ? 23 : _localEndHour;
            totalHours = end - _localStartHour + 1;
          }
          int goalMins = totalHours * 60;

          int totalActive = 0;
          mergedRecords.forEach((key, val) {
            int h = int.parse(key);
            if (_isActive(h)) {
              totalActive += (val as num).toInt();
            }
          });
          int pct = goalMins > 0 ? (totalActive / goalMins * 100).toInt() : 0;

          bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) ==
              DateFormat('yyyyMMdd').format(_now);
          int currentHour = isToday ? _now.hour : -1;
          int currentMin = isToday ? _now.minute : -1;

          // 홈 화면: 스와이프 날짜 이동 없음 (날짜 이동은 상단 화살표 버튼 사용)
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
                      Expanded(
                        flex: 4,
                        child: _buildClockPanel(context, recordsMap),
                      ),
                      Expanded(
                          flex: 8,
                          child: _buildTimeline(recordsMap, currentHour,
                              currentMin, isOvernight)),
                    ],
                  ),
                )
              ],
            ),
          );
        });
  }

  Widget _buildDailyPhraseBanner() {
    if (_dailyPhrase == null || _dailyPhrase!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      // 수정3: 상하 패딩 충분히 확보하여 글자 잘림 방지
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.softIndigo.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softIndigo.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.format_quote_rounded, color: AppTheme.softIndigo, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: MarqueeText(
              text: _dailyPhrase!,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.format_quote_rounded, color: AppTheme.softIndigo, size: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
              Provider.of<LanguageProvider>(context, listen: true).currentLanguage == 'en'
                  ? 'Feel Joongshim Energy'
                  : '중심 유지',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite)),
          const Spacer(),
          // 수정5-1: 메모 아이콘 → 메모 탭으로 이동 (onOpenMemo 콜백 사용)
          IconButton(
            icon: Icon(
              Icons.edit_note_rounded,
              color: _hasMemoToday
                  ? AppTheme.mutedTeal
                  : AppTheme.textGray.withOpacity(0.4),
              size: 28,
            ),
            onPressed: () {
              widget.onOpenMemo?.call(_selectedDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) ==
        DateFormat('yyyyMMdd').format(_now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 날 (날짜에 바로 붙음)
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textWhite),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: () => _changeDate(-1),
          ),
          const SizedBox(width: 4),
          // 날짜 텍스트 (탭하면 달력 피커)
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
                      colorScheme: const ColorScheme.dark(
                          primary: AppTheme.mutedTeal,
                          onPrimary: AppTheme.deepNavy,
                          surface: AppTheme.bgCard,
                          onSurface: AppTheme.textWhite),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _checkMemo();
              }
            },
            child: Column(
              children: [
                Text(DateFormat('yyyy. MM. dd').format(_selectedDate),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite)),
                if (isToday)
                  Text(
                    Provider.of<LanguageProvider>(context, listen: true).currentLanguage == 'en' ? 'Today' : '오늘',
                    style: const TextStyle(fontSize: 12, color: AppTheme.activeGreen)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // 다음 날 (날짜에 바로 붙음)
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: isToday
                    ? AppTheme.textGray.withOpacity(0.3)
                    : AppTheme.textWhite),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: isToday ? null : () => _changeDate(1),
          ),
          // 오늘로 이동 버튼 (과거 날짜일 때만 우측 끝에 표시)
          if (!isToday) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                _flushPending();
                setState(() {
                  _optimisticRecords.clear();
                  _selectedDate = DateTime(_now.year, _now.month, _now.day);
                  _selectedHour = _now.hour;
                  _isNextDaySelected = false;
                  _hasScrolledToCurrentTime = false;
                });
                _scrollToCurrentTime();
                _checkMemo();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.mutedTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.mutedTeal.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.keyboard_double_arrow_right,
                        color: AppTheme.mutedTeal, size: 16),
                    const SizedBox(width: 2),
                    Text(AppStrings.tr(context, '오늘'),
                        style: const TextStyle(
                            color: AppTheme.mutedTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(int totalMins, int pct) {
    int h = totalMins ~/ 60;
    int m = totalMins % 60;
    final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    String timeRangeLabel;
    if (_localEndHour == 24) {
      timeRangeLabel = lang == 'en'
          ? '$_localStartHour am ~ 12 am (midnight)'
          : '$_localStartHour시 ~ 24시(자정)';
    } else if (_isOvernightMode) {
      timeRangeLabel = lang == 'en'
          ? '$_localStartHour am ~ ${_normalizedEndHour} am (next)'
          : '$_localStartHour시 ~ $_normalizedEndHour시(다음날)';
    } else {
      timeRangeLabel = lang == 'en'
          ? '$_localStartHour am ~ $_localEndHour am'
          : '$_localStartHour시 ~ $_localEndHour시';
    }

    return GestureDetector(
      onTap: _showTimeSettings,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
            color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('${h}h ${m}m',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite)),
                    const SizedBox(height: 4),
                    Text(AppStrings.tr(context, '총 유지시간'),
                        style:
                            const TextStyle(color: AppTheme.textGray, fontSize: 12)),
                  ],
                ),
                Container(width: 1, height: 40, color: AppTheme.timelineBg),
                Column(
                  children: [
                    Text('$pct%',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.activeGreen)),
                    const SizedBox(height: 4),
                    Text(AppStrings.tr(context, '유지비중'),
                        style: const TextStyle(
                            color: AppTheme.activeGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.timelineBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: AppTheme.softIndigo),
                        const SizedBox(width: 4),
                        Text('${AppStrings.tr(context, '활동 시간 설정')}: $timeRangeLabel',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textWhite)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppTheme.textGray),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isSaveError ? Colors.redAccent : AppTheme.activeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDailyPhraseBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildClockPanel(BuildContext context, Map<String, dynamic> records) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    final h = _selectedHour;

    // 미선택 상태
    if (h == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, color: AppTheme.textGray, size: 32),
              SizedBox(height: 12),
              Text(
                AppStrings.tr(context, '시간을\n선택하세요'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGray, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    int currentRecord =
        ((mergedRecords[h.toString().padLeft(2, '0')] ?? 0) as num).toInt();
    int pct = (currentRecord / 60 * 100).toInt();
    bool isActiveWindow = _isSelectedHourActive;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left,
                      color: AppTheme.mutedTeal, size: 20),
                  onPressed: h > 0
                      ? () {
                          _flushPending();
                          setState(() => _selectedHour = h - 1);
                        }
                      : null),
              Column(
                children: [
                  Text(h.toString().padLeft(2, '0') + ':00',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                          fontFamily: 'monospace')),
                  Text(AppStrings.tr(context, '선택됨'),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textGray)),
                ],
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right,
                      color: AppTheme.mutedTeal, size: 20),
                  onPressed: h < 23
                      ? () {
                          _flushPending();
                          setState(() => _selectedHour = h + 1);
                        }
                      : null),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isActiveWindow
                          ? AppTheme.activeGreen
                          : AppTheme.textGray.withOpacity(0.5))),
              const SizedBox(width: 4),
              Text('${currentRecord}${AppStrings.tr(context, '분')}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActiveWindow
                          ? AppTheme.textWhite
                          : AppTheme.textGray.withOpacity(0.5))),
            ],
          ),
          if (!isActiveWindow)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(AppStrings.tr(context, '수면 시간'),
                  style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
            )
          else
            const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              double availableHeight = constraints.maxHeight;
              double segmentHeight = availableHeight / 13;
              double dynamicFontSize = (segmentHeight * 0.45).clamp(8.0, 16.0);

              return GestureDetector(
                onVerticalDragUpdate: isActiveWindow
                    ? (details) {
                        double dy = details.localPosition.dy;
                        int index =
                            (dy / availableHeight * 13).floor().clamp(0, 12);
                        _updateEnergy(index * 5);
                      }
                    : null,
                onVerticalDragDown: isActiveWindow
                    ? (details) {
                        double dy = details.localPosition.dy;
                        int index =
                            (dy / availableHeight * 13).floor().clamp(0, 12);
                        _updateEnergy(index * 5);
                      }
                    : null,
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
                            border: Border.all(
                                color: borderColor, width: isSelected ? 2 : 1),
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
            }),
          )
        ],
      ),
    );
  }

  Widget _buildClockPickerPanel(Map<String, dynamic> records) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    final h = _selectedHour;

    // 미선택 상태 (과거 날짜 기본값)
    if (h == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, color: AppTheme.textGray, size: 32),
              SizedBox(height: 12),
              Text(
                '시간을\n선택하세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textGray, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    int currentRecord =
        ((mergedRecords[h.toString().padLeft(2, '0')] ?? 0) as num).toInt();
    bool isActiveWindow = _isSelectedHourActive;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                  icon:
                      const Icon(Icons.chevron_left, color: AppTheme.mutedTeal),
                  onPressed: h > 0
                      ? () {
                          _flushPending();
                          setState(() => _selectedHour = h - 1);
                        }
                      : null),
              Column(
                children: [
                  Text(h.toString().padLeft(2, '0') + ':00',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                          fontFamily: 'monospace')),
                  const Text('selected',
                      style: TextStyle(fontSize: 10, color: AppTheme.textGray)),
                ],
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: AppTheme.mutedTeal),
                  onPressed: h < 23
                      ? () {
                          _flushPending();
                          setState(() => _selectedHour = h + 1);
                        }
                      : null),
            ],
          ),
          const SizedBox(height: 12),
          if (!isActiveWindow)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(AppStrings.tr(context, '수면 시간'),
                  style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
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

  Widget _buildTimeline(Map<String, dynamic> records, int currentHour,
      int currentMin, bool isOvernight) {
    Map<String, dynamic> mergedRecords = Map.from(records);
    _optimisticRecords.forEach((key, val) => mergedRecords[key] = val);

    // 자정 초과: 0~23 + 다음날 0~(normalizedEndHour-1) 표시
    List<int> hours = List.generate(24, (i) => i);
    List<bool> isNextDay = List.generate(24, (_) => false);

    if (isOvernight) {
      // 다음날 새벽 시간 추가: 0 ~ normalizedEndHour-1 (취침시각 제외)
      for (int h = 0; h < _normalizedEndHour; h++) {
        hours.add(h);
        isNextDay.add(true);
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: ListView.builder(
        controller: _timelineScrollController,
        itemCount: hours.length,
        itemBuilder: (context, index) {
          int hour = hours[index];
          bool nextDay = isNextDay[index];
          int record =
              ((mergedRecords[hour.toString().padLeft(2, '0')] ?? 0) as num)
                  .toInt();

          // 자정 구분선 표시
          bool showMidnightDivider = isOvernight && index == 24;

          // 활동 시간 여부
          bool activeWindow;
          if (_isFutureTime(hour, nextDay)) {
            activeWindow = false; // 현재 시간 이후는 비활성
          } else if (nextDay) {
            activeWindow = true; // 다음날 구간: 항상 활성 (0~endHour-1)
          } else if (isOvernight) {
            activeWindow = hour >= _localStartHour; // 일반 구간: startHour 이상만 활성
          } else {
            activeWindow = _isActive(hour);
          }

          // 선택 상태: 같은 hour라도 일반/다음날 구간 구분
          bool selected =
              _selectedHour == hour && (nextDay == _isNextDaySelected);

          return Column(
            children: [
              if (showMidnightDivider) _buildMidnightDivider(),
              TimelineRow(
                hour: hour,
                minutes: record,
                isSelected: selected,
                isCurrent: currentHour == hour && !nextDay,
                currentMinute: currentMin,
                isActiveWindow: activeWindow,
                isNextDay: nextDay,
                onTap: () {
                  _flushPending();
                  setState(() {
                    _selectedHour = hour;
                    _isNextDaySelected = nextDay; // 다음날 구간인지 기록
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMidnightDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Container(
                  height: 1, color: AppTheme.softIndigo.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              AppStrings.tr(context, '자정 (다음날)'),
              style: TextStyle(
                color: AppTheme.softIndigo.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
              child: Container(
                  height: 1, color: AppTheme.softIndigo.withOpacity(0.3))),
        ],
      ),
    );
  }
}
