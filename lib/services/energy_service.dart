import 'package:cloud_firestore/cloud_firestore.dart';

class EnergyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateEnergyLog({
    required String userId,
    required DateTime date,
    required int hour,
    required int minutes,
    required int startHour,
    required int endHour,
  }) async {
    String dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    DocumentReference logRef = _db.collection('users').doc(userId).collection('daily_logs').doc(dateId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(logRef);
      Map<String, dynamic> records = {};
      int sH = startHour;
      int eH = endHour;

      if (snapshot.exists) {
        records = Map<String, dynamic>.from((snapshot.data() as Map<String, dynamic>)['records'] ?? {});
        sH = startHour;
        eH = endHour;
      }

      if (hour >= 0) {
        String hourKey = hour.toString().padLeft(2, '0');
        records[hourKey] = minutes;
      }

      // 자정 초과 여부 판단 (endHour < startHour 또는 endHour >= 24로 인코딩된 다음날)
      bool isOvernight = eH < sH || eH >= 24;
      // 실제 취침 시간 (24+h 인코딩 해제)
      int actualEnd = eH >= 24 ? eH - 24 : eH;

      // 활동 시간 여부 헬퍼
      bool isActive(int h) {
        if (isOvernight) {
          return h >= sH || h < actualEnd;  // actualEnd 자체는 취침 시간이므로 불포함
        } else {
          int end = eH == 24 ? 23 : eH;
          return h >= sH && h <= end;
        }
      }

      int totalActiveMinutes = 0;
      records.forEach((key, value) {
        int h = int.parse(key);
        if (isActive(h)) {
          totalActiveMinutes += (value as num).toInt();
        }
      });

      // 목표 시간 계산 (자정 초과 포함)
      int goalMinutes;
      if (isOvernight) {
        goalMinutes = ((24 - sH) + actualEnd) * 60;
      } else {
        int end = eH == 24 ? 23 : eH;
        goalMinutes = (end - sH + 1) * 60;
      }
      double efficiency = goalMinutes > 0 ? (totalActiveMinutes / goalMinutes) * 100 : 0.0;

      transaction.set(logRef, {
        'date': dateId,
        'records': records,
        'totalActiveMinutes': totalActiveMinutes,
        'efficiencyPct': efficiency.clamp(0.0, 100.0).toDouble(),
        'startHour': sH,
        'endHour': eH,
      }, SetOptions(merge: true));
    });
  }

  Stream<DocumentSnapshot> getDailyLogStream(String userId, String dateId) {
    return _db.collection('users').doc(userId).collection('daily_logs').doc(dateId).snapshots();
  }

  /// 특정 날짜의 daily_log를 1회 조회 (인접 날짜 제약 확인용)
  Future<Map<String, dynamic>?> getDailyLogOnce(String userId, DateTime date) async {
    String dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final doc = await _db.collection('users').doc(userId).collection('daily_logs').doc(dateId).get();
    if (doc.exists) return doc.data() as Map<String, dynamic>;
    return null;
  }

  Stream<QuerySnapshot> getLogsStream(String userId, DateTime start, DateTime end) {
    String startId = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    String endId = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
    
    return _db.collection('users')
      .doc(userId)
      .collection('daily_logs')
      .where('date', isGreaterThanOrEqualTo: startId)
      .where('date', isLessThanOrEqualTo: endId)
      .snapshots();
  }

  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    var doc = await _db.collection('users').doc(userId).collection('settings').doc('default').get();
    if (doc.exists) return doc.data() as Map<String, dynamic>;
    return {'startHour': 7, 'endHour': 24, 'alarmInterval': 60, 'alarmOn': true, 'inputType': 'bar'};
  }

  Future<void> updateUserSettings(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).collection('settings').doc('default').set(data, SetOptions(merge: true));
  }
}
