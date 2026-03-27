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
