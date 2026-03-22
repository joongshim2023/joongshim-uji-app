import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;

/// 앱 버전 업데이트 체크 서비스
/// Firestore `app_config/version` 문서를 기반으로 업데이트 여부를 판단합니다.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _docPath = 'app_config/version';

  /// 업데이트 체크 결과
  Future<UpdateCheckResult> checkForUpdate() async {
    if (kIsWeb) return UpdateCheckResult.none();

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;         // e.g. "1.2.2"
      final currentBuild = int.tryParse(info.buildNumber) ?? 0; // e.g. 8

      final doc = await FirebaseFirestore.instance.doc(_docPath).get();
      if (!doc.exists) {
        debugPrint('[업데이트] app_config/version 문서 없음 → 체크 건너뜀');
        return UpdateCheckResult.none();
      }

      final data = doc.data()!;
      final String latestVersion = data['latestVersion'] ?? currentVersion;
      final int latestBuild = (data['latestBuildNumber'] ?? currentBuild) as int;
      final String minVersion = data['minVersion'] ?? '1.0.0';
      final bool forceUpdate = data['forceUpdate'] ?? false;
      final String message = data['message'] ?? '새로운 버전이 출시되었습니다! 업데이트 후 더 좋은 경험을 누려보세요.';
      final String androidUrl = data['androidStoreUrl'] ?? 'market://details?id=com.uji.joongshim';
      final String iosUrl = data['iosStoreUrl'] ?? 'https://apps.apple.com/app/id6744050393';

      debugPrint('[업데이트] 현재=$currentVersion+$currentBuild, 최신=$latestVersion+$latestBuild, min=$minVersion, force=$forceUpdate');

      // 강제 업데이트: 현재 버전이 최소 버전보다 낮을 때
      if (_compareVersions(currentVersion, minVersion) < 0) {
        return UpdateCheckResult(
          hasUpdate: true,
          forceUpdate: true,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          message: message,
          storeUrl: Platform.isAndroid ? androidUrl : iosUrl,
        );
      }

      // 선택 업데이트: 최신 빌드보다 낮을 때
      if (latestBuild > currentBuild) {
        return UpdateCheckResult(
          hasUpdate: true,
          forceUpdate: forceUpdate,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          message: message,
          storeUrl: Platform.isAndroid ? androidUrl : iosUrl,
        );
      }

      debugPrint('[업데이트] 최신 버전 사용 중');
      return UpdateCheckResult.none();
    } catch (e) {
      debugPrint('[업데이트] 체크 실패: $e');
      return UpdateCheckResult.none();
    }
  }

  /// 버전 문자열 비교: a < b → 음수, a == b → 0, a > b → 양수
  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}

class UpdateCheckResult {
  final bool hasUpdate;
  final bool forceUpdate;
  final String? latestVersion;
  final String? currentVersion;
  final String? message;
  final String? storeUrl;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.forceUpdate = false,
    this.latestVersion,
    this.currentVersion,
    this.message,
    this.storeUrl,
  });

  factory UpdateCheckResult.none() => const UpdateCheckResult(hasUpdate: false);
}
