class UserProfile {
  final String userId;
  final String userName;
  final int startHour;
  final int endHour;
  final int reminderInterval;

  UserProfile({
    required this.userId,
    required this.userName,
    this.startHour = 7,
    this.endHour = 23,
    this.reminderInterval = 60,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      userId: documentId,
      userName: data['userName'] ?? 'User',
      startHour: data['startHour'] ?? 7,
      endHour: data['endHour'] ?? 23,
      reminderInterval: data['reminderInterval'] ?? 60,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'startHour': startHour,
      'endHour': endHour,
      'reminderInterval': reminderInterval,
    };
  }
}
