import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/memo_service.dart';

class MemoScreen extends StatefulWidget {
  final DateTime initialDate;
  final String userId;
  final bool isTab; // true: 탭으로 사용, false: push 모달로 사용

  const MemoScreen({
    Key? key,
    required this.initialDate,
    required this.userId,
    this.isTab = false,
  }) : super(key: key);

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen>
    with TickerProviderStateMixin {
  final MemoService _memoService = MemoService();
  late DateTime _selectedDate;
  late TextEditingController _textController;
  String _savedContent = '';
  DateTime? _lastUpdatedAt;
  bool _isLoading = true;
  bool _isSaving = false;

  // 날짜 전환 애니메이션
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // 날짜바 반짝임 애니메이션
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _textController = TextEditingController();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // 반짝임 컨트롤러: 0→1→0
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeInOut));

    _loadMemo();
  }

  @override
  void dispose() {
    _textController.dispose();
    _slideController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  String get _dateKey =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);

  bool get _hasUnsavedChanges =>
      _textController.text != _savedContent;

  Future<void> _loadMemo() async {
    setState(() => _isLoading = true);
    final data = await _memoService.getMemoOnce(widget.userId, _dateKey);
    if (mounted) {
      final content = data?['content'] ?? '';
      final updatedAt = data?['updatedAt'];
      setState(() {
        _savedContent = content;
        _textController.text = content;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: content.length),
        );
        if (updatedAt is Timestamp) {
          _lastUpdatedAt = updatedAt.toDate();
        } else {
          _lastUpdatedAt = null;
        }
        _isLoading = false;
      });
    }
  }

  Future<bool> _confirmUnsavedChanges() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '저장하지 않은 내용이 있습니다.',
          style: TextStyle(color: AppTheme.textWhite, fontSize: 16),
        ),
        content: const Text(
          '저장하지 않고 나가시겠습니까?',
          style: TextStyle(color: AppTheme.textGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 날짜 직접 이동 (화살표 버튼용: 하루씩 이동)
  Future<void> _changeDate(int delta) async {
    if (!await _confirmUnsavedChanges()) return;

    final newDate = _selectedDate.add(Duration(days: delta));
    // 미래 날짜 금지
    if (newDate.isAfter(DateTime.now())) return;

    // 슬라이드 애니메이션
    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(delta > 0 ? 1.0 : -1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));
      _selectedDate = newDate;
    });
    _slideController.forward(from: 0.0);
    _flashDateNav();
    await _loadMemo();
  }

  /// 스와이프로 메모 있는 날로 이동 (delta: -1=이전, 1=다음)
  Future<void> _swipeToMemoDate(int delta) async {
    if (!await _confirmUnsavedChanges()) return;

    final currentKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String? targetKey;

    if (delta < 0) {
      targetKey = await _memoService.getPrevMemoDate(widget.userId, currentKey);
    } else {
      targetKey = await _memoService.getNextMemoDate(widget.userId, currentKey);
    }

    if (targetKey == null) {
      // 더 이상 메모 있는 날 없음 → 팝업
      if (mounted) {
        _showNoMoreMemoDialog(delta < 0 ? '이전' : '이후');
      }
      return;
    }

    // 미래 날짜 금지
    final targetDate = DateTime.parse(targetKey);
    if (targetDate.isAfter(DateTime.now())) {
      if (mounted) _showNoMoreMemoDialog('이후');
      return;
    }

    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(delta > 0 ? 1.0 : -1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));
      _selectedDate = targetDate;
    });
    _slideController.forward(from: 0.0);
    _flashDateNav();
    await _loadMemo();
  }

  /// 날짜 네비게이션 바 반짝임 효과
  void _flashDateNav() {
    _flashController.forward(from: 0.0);
  }

  /// 메모 없는 날 스와이프 시 안내 팝업
  void _showNoMoreMemoDialog(String direction) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.softIndigo, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$direction 방향으로 메모 있는 날이 없습니다.',
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(color: AppTheme.mutedTeal)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMemo() async {
    final content = _textController.text;
    setState(() => _isSaving = true);
    try {
      await _memoService.saveMemo(widget.userId, _dateKey, content);
      if (mounted) {
        setState(() {
          _savedContent = content;
          _lastUpdatedAt = DateTime.now();
          _isSaving = false;
        });
        _showToast('저장되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('저장 실패: $e');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: AppTheme.textWhite)),
        backgroundColor: AppTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isToday = DateFormat('yyyyMMdd').format(_selectedDate) ==
        DateFormat('yyyyMMdd').format(DateTime.now());

    final body = SafeArea(
      child: Column(
        children: [
          _buildHeader(isToday),
          _buildDateNav(isToday),
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.mutedTeal))
                  : _buildMemoArea(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );

    // 탭 모드 vs 모달 모드
    if (widget.isTab) {
      // 탭: PopScope/뒤로가기 다이얼로그 없이 바로 Scaffold
      return Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: kIsWeb
            ? body
            : GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (_hasUnsavedChanges) return;
                  final dx = details.primaryVelocity ?? 0;
                  if (dx < -300) {
                    _swipeToMemoDate(1);
                  } else if (dx > 300) {
                    _swipeToMemoDate(-1);
                  }
                },
                child: body,
              ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmUnsavedChanges()) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: kIsWeb
            ? body
            : GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (_hasUnsavedChanges) return;
                  final dx = details.primaryVelocity ?? 0;
                  if (dx < -300) {
                    _swipeToMemoDate(1);
                  } else if (dx > 300) {
                    _swipeToMemoDate(-1);
                  }
                },
                onVerticalDragEnd: (details) {
                  final dy = details.primaryVelocity ?? 0;
                  if (dy > 500) {
                    _confirmUnsavedChanges().then((ok) {
                      if (ok && mounted) Navigator.pop(context);
                    });
                  }
                },
                child: body,
              ),
      ),
    );
  }

  Widget _buildHeader(bool isToday) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 탭 모드에서는 뒤로가기 버튼 숨기기
          if (!widget.isTab) ...[
            GestureDetector(
              onTap: () async {
                if (await _confirmUnsavedChanges()) {
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: AppTheme.textWhite, size: 18),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // 아이콘 제거, 설정/통계 화면과 동일한 평체 헤더
          const Text(
            '메모',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite),
          ),
          const Spacer(),
          if (_hasUnsavedChanges)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.mutedTeal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.mutedTeal.withOpacity(0.4)),
              ),
              child: const Text('미저장',
                  style:
                      TextStyle(color: AppTheme.mutedTeal, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildDateNav(bool isToday) {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        final flashOpacity = _flashAnimation.value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.softIndigo.withOpacity(flashOpacity * 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 날 (날짜에 바로 붙음)
          IconButton(
            icon: const Icon(Icons.chevron_left,
                color: AppTheme.textWhite),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: () => _changeDate(-1),
          ),
          const SizedBox(width: 4),
          // 날짜 텍스트 (탭 → 달력 팝업)
          InkWell(
            onTap: () async {
              if (!await _confirmUnsavedChanges()) return;
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.mutedTeal,
                        onPrimary: AppTheme.deepNavy,
                        surface: AppTheme.bgCard,
                        onSurface: AppTheme.textWhite,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && mounted) {
                final delta = picked.isAfter(_selectedDate) ? 1 : -1;
                setState(() {
                  _slideAnimation = Tween<Offset>(
                    begin: Offset(delta.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _slideController,
                    curve: Curves.easeOutCubic,
                  ));
                  _selectedDate = picked;
                });
                _slideController.forward(from: 0.0);
                _flashDateNav();
                await _loadMemo();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  Text(
                    DateFormat('yyyy. MM. dd').format(_selectedDate),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite),
                  ),
                  Text(
                    isToday ? '오늘' : '과거 기록',
                    style: TextStyle(
                        fontSize: 12,
                        color: isToday
                            ? AppTheme.activeGreen
                            : AppTheme.softIndigo),
                  ),
                ],
              ),
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
          // 오늘로 이동 버튼 (과거 날짜일 때만 우측에 표시)
          if (!isToday) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () async {
                if (!await _confirmUnsavedChanges()) return;
                final today = DateTime.now();
                setState(() {
                  _slideAnimation = Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _slideController,
                    curve: Curves.easeOutCubic,
                  ));
                  _selectedDate = DateTime(today.year, today.month, today.day);
                });
                _slideController.forward(from: 0.0);
                _flashDateNav();
                await _loadMemo();
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
                  children: const [
                    Icon(Icons.keyboard_double_arrow_right,
                        color: AppTheme.mutedTeal, size: 16),
                    SizedBox(width: 2),
                    Text('오늘',
                        style: TextStyle(
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

  Widget _buildMemoArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 16,
                height: 1.7,
              ),
              decoration: InputDecoration(
                hintText: '이 날의 메모를 남겨보세요...',
                hintStyle: TextStyle(
                    color: AppTheme.textGray.withOpacity(0.5),
                    fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_lastUpdatedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12,
                      color: AppTheme.textGray.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    '마지막 수정: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastUpdatedAt!)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveMemo,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mutedTeal,
            disabledBackgroundColor: AppTheme.mutedTeal.withOpacity(0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text(
                  '저장하기',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepNavy),
                ),
        ),
      ),
    );
  }
}
