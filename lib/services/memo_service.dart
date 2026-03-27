import 'package:cloud_firestore/cloud_firestore.dart';

class MemoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _memoRef(String userId, String dateId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('daily_memos')
        .doc(dateId);
  }

  Stream<DocumentSnapshot> getMemoStream(String userId, String dateId) {
    return _memoRef(userId, dateId).snapshots();
  }

  Future<Map<String, dynamic>?> getMemoOnce(
      String userId, String dateId) async {
    final doc = await _memoRef(userId, dateId).get();
    if (doc.exists) return doc.data() as Map<String, dynamic>;
    return null;
  }

  Future<void> saveMemo(String userId, String dateId, String content) async {
    final ref = _memoRef(userId, dateId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.update({
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 메모가 존재하는 모든 날짜 ID(yyyy-MM-dd) 목록 반환 (정렬됨)
  Future<List<String>> getMemoDatesSorted(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('daily_memos')
        .get();
    final dates = snapshot.docs
        .where((doc) {
          final content = (doc.data()['content'] as String? ?? '').trim();
          return content.isNotEmpty;
        })
        .map((doc) => doc.id)
        .toList()
      ..sort();
    return dates;
  }

  /// [currentDateId] 기준으로 이전 메모 날짜 반환 (없으면 null)
  Future<String?> getPrevMemoDate(String userId, String currentDateId) async {
    final dates = await getMemoDatesSorted(userId);
    final earlier = dates.where((d) => d.compareTo(currentDateId) < 0).toList();
    if (earlier.isEmpty) return null;
    return earlier.last;
  }

  /// [currentDateId] 기준으로 다음 메모 날짜 반환 (없으면 null)
  Future<String?> getNextMemoDate(String userId, String currentDateId) async {
    final dates = await getMemoDatesSorted(userId);
    final later = dates.where((d) => d.compareTo(currentDateId) > 0).toList();
    if (later.isEmpty) return null;
    return later.first;
  }

  /// 날짜별 메모 목록 조회 (내보내기용)
  Future<List<Map<String, dynamic>>> getMemosInRange(
      String userId, DateTime start, DateTime end) async {
    String startId =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    String endId =
        "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('daily_memos')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'date': doc.id,
        'content': data['content'] ?? '',
        'updatedAt': data['updatedAt'],
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }
}
