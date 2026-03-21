class EnergyLog {
  final String logId;
  final String userId;
  final String date; // YYYY-MM-DD
  final int totalActiveMinutes;
  final double efficiencyPct;
  final Map<String, int> records; // e.g., "H07": 45

  EnergyLog({
    required this.logId,
    required this.userId,
    required this.date,
    this.totalActiveMinutes = 0,
    this.efficiencyPct = 0.0,
    this.records = const {},
  });

  factory EnergyLog.fromMap(Map<String, dynamic> data, String documentId) {
    Map<String, int> parsedRecords = {};
    if (data['records'] != null) {
      final Map<String, dynamic> rawRecords = data['records'];
      rawRecords.forEach((key, value) {
        parsedRecords[key] = (value as num).toInt();
      });
    }

    return EnergyLog(
      logId: documentId,
      userId: data['userId'] ?? '',
      date: data['date'] ?? '',
      totalActiveMinutes: (data['totalActiveMinutes'] ?? 0).toInt(),
      efficiencyPct: (data['efficiencyPct'] ?? 0.0).toDouble(),
      records: parsedRecords,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'totalActiveMinutes': totalActiveMinutes,
      'efficiencyPct': efficiencyPct,
      'records': records,
    };
  }
}
