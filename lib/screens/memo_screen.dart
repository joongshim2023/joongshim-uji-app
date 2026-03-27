import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/memo_service.dart';

class MemoScreen extends StatefulWidget {
  final DateTime initialDate;
  final String userId;

  const MemoScreen({
    Key? key,
    required this.initialDate,
    required this.userId,
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
    _loadMemo();
  }

  @override
  void dispose() {
    _textController.dispose();
    _slideController.dispose();
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
    await _loadMemo();
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
        body: SafeArea(
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
        ),
      ),
    );
  }

  Widget _buildHeader(bool isToday) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
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
          const Icon(Icons.edit_note_rounded,
              color: AppTheme.mutedTeal, size: 24),
          const SizedBox(width: 8),
          const Text(
            '메모',
            style: TextStyle(
                fontSize: 22,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left,
                color: AppTheme.textWhite),
            onPressed: () => _changeDate(-1),
          ),
          Column(
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
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: isToday
                    ? AppTheme.textGray.withOpacity(0.3)
                    : AppTheme.textWhite),
            onPressed: isToday ? null : () => _changeDate(1),
          ),
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
