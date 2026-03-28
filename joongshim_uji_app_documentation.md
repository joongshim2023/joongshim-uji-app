# 중심 유지 App — 종합 문서

> **버전** v1.3.3+20 · **최종 업데이트** 2026-03-28

---

## 목차

1. [앱 개요](#1-앱-개요)
2. [주요 기능](#2-주요-기능)
3. [화면 구조](#3-화면-구조)
4. [기술 스택](#4-기술-스택)
5. [아키텍처](#5-아키텍처)
6. [서비스 레이어](#6-서비스-레이어)
7. [Firestore 데이터 모델](#7-firestore-데이터-모델)
8. [알림 시스템](#8-알림-시스템)
9. [테마 & 디자인 시스템](#9-테마--디자인-시스템)
10. [빌드 & 배포](#10-빌드--배포)
11. [보안 파일 관리](#11-보안-파일-관리)

---

## 1. 앱 개요

**중심 유지 App**은 사용자가 매 시간 자신의 "에너지감각 유지 비중"을 기록하고, 하루·주간 단위로 추이를 분석할 수 있도록 돕는 자기 관리 앱입니다.

| 항목 | 내용 |
|---|---|
| 앱 이름 | 중심 유지 App |
| 패키지 이름 | `com.uji.joongshim` |
| 플랫폼 | Android / iOS (+ Web 읽기 전용) |
| 최소 SDK | Android (Gradle 8.13 / AGP 8.11.1), iOS |
| Flutter | 3.41.5 (Dart 3.11.3) |
| 앱 스토어 (iOS) | https://apps.apple.com/app/id6744050393 |
| 앱 스토어 (Android) | `market://details?id=com.uji.joongshim` |

---

## 2. 주요 기능

### 2.1 에너지감각 유지 기록 (홈 화면)
- 시간대별(0시~23시) 유지 비중(0~60분)을 바(bar) 형태로 입력
- 기상 시간 / 취침 시간 설정 → 활동 시간 외 구간은 "수면 시간"으로 표시
- **자정 초과 모드**: 취침이 다음날 새벽인 경우 자동 처리 (예: 기상 7시, 취침 1시(다음날))
- 하루 총 유지시간(h m) 및 유지 비중(%) 실시간 표시
- **Optimistic UI**: 저장 전 즉시 화면 반영, 300ms debounce 후 Firestore 저장
- **Daily Wisdom 배너**: Firestore `app_config/sentence`에서 매일 다른 문구 표시 (날짜+UID seed 기반 결정론적 선택)

### 2.2 날짜 이동
- 상단 `<` / `>` 버튼: 하루씩 이동
- 날짜 텍스트 탭: DatePicker로 직접 선택
- 홈 화면: 좌우 스와이프 날짜 이동 없음 (의도적 제거)

### 2.3 메모 (메모장 화면)
- 날짜별 자유 형식 메모 작성 및 저장
- `<` / `>` 버튼: 하루씩 이동
- **좌우 스와이프**: 메모가 존재하는 날짜로만 이동 (빈 날 건너뜀)
  - 이동 성공 시 날짜 바 indigo 반짝임 효과 (600ms)
  - 더 이상 메모 날이 없으면 안내 팝업 표시
- 아래 스와이프: 화면 닫기
- 미저장 내용 있을 때 이탈 시 확인 다이얼로그

### 2.4 통계 분석 (통계 화면)
- **캘린더 뷰**: 월별 날짜 격자, 각 날짜에 유지 비중(%) 표시
  - 메모 있는 날: teal 배경 틴트
  - 오늘: yellow 테두리
- **그래프 뷰**: 주간 라인 차트 (fl_chart), 날짜별 유지 비중 추이

### 2.5 설정 화면
- 기상/취침 시간 설정 (전역 기본값)
- 알림 ON/OFF, 주기 설정 (30분 / 60분)
- 활동 기록 CSV 내보내기 (기간 선택)
- 메모 CSV 내보내기 (기간 선택)
- 프로필 (이메일 확인, 비밀번호 재설정)
- 개인정보처리방침 열람 (in-app WebView)
- 계정 삭제 (재인증 후 Firestore 데이터 완전 삭제)
- 앱 버전 표시

### 2.6 인증
- 이메일/비밀번호 로그인·회원가입
- Google 소셜 로그인
- Apple 소셜 로그인 (iOS 필수, Apple 심사 요건)
- 비밀번호 재설정 이메일 발송

### 2.7 앱 업데이트
- **Android**: Google Play In-App Update API (즉시 업데이트)
- **iOS + Android 폴백**: Firestore `app_config/version` 기반 커스텀 업데이트 팝업
  - `minVersion` 미만이면 강제 업데이트 (닫기 불가)
  - 그 외 최신 버전 있으면 선택 업데이트

### 2.8 알림 (리마인더)
- 활동 시간 내 매 시간(또는 30분)마다 푸시 알림
- Android: exact alarm 권한 확인, 없으면 inexact 폴백
- iOS: 최대 64개 알림 예약 제한 준수
- 알림 설정 변경 시 중복 재등록 방지 (SharedPreferences 캐시)
- Firestore `alarm_logs` / `error_logs` 에 이벤트 기록

---

## 3. 화면 구조

```
JoongshimUjiApp (MaterialApp)
├── LoginScreen          ← 미인증 상태
└── MainNavigator        ← 인증 완료 상태
    ├── [탭 0] HomeScreen       ← 메인 기록 화면
    │   └── MemoScreen (push)   ← 메모 작성 (슬라이드업 전환)
    ├── [탭 1] TrendScreen      ← 통계 (캘린더/그래프)
    └── [탭 2] SettingsScreen   ← 설정
        └── PrivacyPolicyScreen (push)
```

### 탭 바 항목
| 인덱스 | 아이콘 | 이름 |
|---|---|---|
| 0 | `home` | 홈 |
| 1 | `insights` | 통계 |
| 2 | `settings` | 설정 |

---

## 4. 기술 스택

### 핵심 프레임워크
| 패키지 | 버전 | 용도 |
|---|---|---|
| Flutter | 3.41.5 | 크로스플랫폼 UI |
| Dart | 3.11.3 | 언어 |

### Firebase
| 패키지 | 버전 | 용도 |
|---|---|---|
| `firebase_core` | 4.5.0 | Firebase 초기화 |
| `firebase_auth` | 6.2.0 | 인증 |
| `cloud_firestore` | 6.1.3 | 데이터베이스 |
| `firebase_messaging` | 16.1.2 | 푸시 메시지 (기반) |
| `firebase_crashlytics` | 5.0.8 | 크래시 리포팅 |

### 인증
| 패키지 | 버전 | 용도 |
|---|---|---|
| `google_sign_in` | 7.2.0 | Google 로그인 |
| `sign_in_with_apple` | 6.1.3 | Apple 로그인 |

### UI / 차트
| 패키지 | 버전 | 용도 |
|---|---|---|
| `fl_chart` | 1.2.0 | 주간 라인 차트 |
| `webview_flutter` | 4.10.0 | 개인정보처리방침 뷰어 |

### 알림
| 패키지 | 버전 | 용도 |
|---|---|---|
| `flutter_local_notifications` | 17.2.4 | 로컬 푸시 알림 |
| `timezone` | 0.9.4 | Asia/Seoul 시간대 |

### 유틸리티
| 패키지 | 버전 | 용도 |
|---|---|---|
| `intl` | 0.20.2 | 날짜 포맷 |
| `provider` | 6.1.1 | 상태 관리 |
| `shared_preferences` | 2.5.4 | 알림 캐시 |
| `package_info_plus` | 8.1.3 | 앱 버전 조회 |
| `url_launcher` | 6.3.1 | 스토어 링크 열기 |
| `share_plus` | 12.0.1 | CSV 내보내기 |
| `path_provider` | 2.1.5 | 임시 파일 경로 |
| `in_app_update` | 4.2.5 | Android In-App Update |

---

## 5. 아키텍처

```
lib/
├── main.dart               # 앱 진입점, Firebase 초기화, 라우팅
├── firebase_options.dart   # FlutterFire 자동 생성 설정
├── theme/
│   └── app_theme.dart      # 전역 색상 토큰 및 ThemeData
├── models/
│   ├── energy_log.dart     # EnergyLog 모델
│   └── user_profile.dart   # UserProfile 모델
├── services/
│   ├── auth_service.dart         # Firebase Auth 래퍼
│   ├── energy_service.dart       # Firestore 에너지 로그 CRUD
│   ├── memo_service.dart         # Firestore 메모 CRUD + 날짜 탐색
│   ├── notification_service.dart # 로컬 알림 예약/취소/로그
│   └── update_service.dart       # 앱 버전 업데이트 체크
├── screens/
│   ├── home_screen.dart          # 메인 기록 화면
│   ├── memo_screen.dart          # 메모 작성 화면
│   ├── trend_screen.dart         # 통계 화면
│   ├── settings_screen.dart      # 설정 화면
│   ├── login_screen.dart         # 로그인 화면
│   └── privacy_policy_screen.dart
└── widgets/
    ├── energy_clock_picker.dart  # 원형 에너지 입력 위젯
    ├── timeline_row.dart         # 시간대별 타임라인 행
    └── marquee_text.dart         # 자동 스크롤 텍스트 (daily phrase)
```

### 상태 관리 전략
- **로컬 상태**: `StatefulWidget` + `setState` (단순 UI 상태)
- **실시간 DB 동기화**: `StreamBuilder<DocumentSnapshot>` (홈/통계)
- **Optimistic UI**: 홈 화면의 `_optimisticRecords` Map — 저장 대기 중인 값을 즉시 반영
- **인증 상태**: `StreamBuilder<User?>` (main.dart의 `authStateChanges`)

### 핵심 설계 패턴
| 패턴 | 적용 위치 |
|---|---|
| Singleton | [NotificationService](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/notification_service.dart#10-353), [UpdateService](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/update_service.dart#8-92) |
| Repository | [AuthService](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#6-148), [EnergyService](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#3-155), [MemoService](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#3-103) |
| Debounce | 에너지 입력 저장 (300ms) |
| Optimistic Update | 홈 화면 에너지 기록 |
| Observer (Stream) | Firestore 실시간 리스닝 |

---

## 6. 서비스 레이어

### 6.1 AuthService ([auth_service.dart](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart))

| 메서드 | 설명 |
|---|---|
| [signInWithEmailPassword(email, pw)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#13-18) | 이메일 로그인 |
| [registerWithEmailPassword(email, pw)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#19-24) | 이메일 회원가입 |
| [sendPasswordReset(email)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#25-28) | 비밀번호 재설정 메일 발송 |
| [signInWithGoogle()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#29-43) | Google OAuth |
| [signInWithApple()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#44-56) | Apple OAuth |
| [reauthenticateWithPassword(email, pw)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#77-85) | 이메일 사용자 재인증 |
| [reauthenticateWithGoogle()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#86-101) | Google 재인증 |
| [reauthenticateWithApple()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#102-114) | Apple 재인증 |
| [deleteAccount()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#57-76) | Firestore 데이터 삭제 → Auth 계정 삭제 |
| [signOut()](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/auth_service.dart#141-147) | 로그아웃 |

> **계정 삭제 절차**: Firestore `daily_logs` / `alarm_logs` / `settings` 서브컬렉션 → 유저 도큐먼트 → Firebase Auth 계정 순으로 삭제

### 6.2 EnergyService ([energy_service.dart](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart))

| 메서드 | 설명 |
|---|---|
| [updateEnergyLog(...)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#6-87) | 특정 날짜·시간의 에너지 기록 저장 (Firestore Transaction) |
| [getDailyLogStream(userId, dateId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#88-96) | 날짜별 로그 실시간 스트림 |
| [getDailyLogOnce(userId, date)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#97-111) | 날짜별 로그 1회 조회 |
| [getLogsStream(userId, start, end)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#112-127) | 기간별 로그 스트림 (통계용) |
| [getUserSettings(userId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#128-144) | 사용자 기본 설정 조회 |
| [updateUserSettings(userId, data)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/energy_service.dart#145-154) | 사용자 설정 업데이트 |

**유지 비중 계산 로직**:
```
goalMinutes = (활동 시간대 총 시간) × 60
efficiency  = totalActiveMinutes / goalMinutes × 100 (0~100 클램프)
```

자정 초과(overnight) 모드:
- `endHour < startHour` 또는 `endHour >= 24` (24+h 인코딩)
- `goalMinutes = (24 - startHour + actualEnd) × 60`

### 6.3 MemoService ([memo_service.dart](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart))

| 메서드 | 설명 |
|---|---|
| [getMemoStream(userId, dateId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#14-17) | 날짜별 메모 실시간 스트림 |
| [getMemoOnce(userId, dateId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#18-24) | 날짜별 메모 1회 조회 |
| [saveMemo(userId, dateId, content)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#25-41) | 메모 저장 (없으면 set, 있으면 update) |
| [getMemoDatesSorted(userId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#42-59) | 메모 있는 날짜 정렬 목록 (스와이프 이동용) |
| [getPrevMemoDate(userId, currentDateId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#60-67) | 이전 메모 날짜 |
| [getNextMemoDate(userId, currentDateId)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#68-75) | 다음 메모 날짜 |
| [getMemosInRange(userId, start, end)](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/memo_service.dart#76-102) | 기간별 메모 목록 (CSV 내보내기용) |

### 6.4 NotificationService ([notification_service.dart](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/notification_service.dart))

싱글턴. 알림 초기화, 권한 요청, 시간대별 알림 예약/취소를 담당.

**알림 예약 전략**:
1. SharedPreferences로 이전 설정과 비교 → 동일하고 예약 알림 존재 시 건너뜀
2. 기존 알림 전체 취소 후 재예약
3. 활동 시간대의 매 정각(±30분 옵션) 슬롯 생성
4. iOS 최대 64개 제한, Android 500개

**Android 알림 모드**:
- `exactAllowWhileIdle` (정밀 알람 권한 있음)
- `inexactAllowWhileIdle` (권한 없음, 폴백)

### 6.5 UpdateService ([update_service.dart](file:///Users/jahyun/developer/joongshim-uji-app/lib/services/update_service.dart))

싱글턴. Firestore `app_config/version` 문서를 기준으로 업데이트 필요 여부를 판별.

**Firestore 필드**:
| 필드 | 타입 | 설명 |
|---|---|---|
| `latestVersion` | String | 최신 버전 (e.g. "1.3.3") |
| `latestBuildNumber` | int | 최신 빌드 번호 |
| `minVersion` | String | 강제 업데이트 최소 버전 |
| `forceUpdate` | bool | 강제 업데이트 여부 |
| `message` | String | 팝업 메시지 |
| `androidStoreUrl` | String | Android 스토어 URL |
| `iosStoreUrl` | String | iOS 스토어 URL |

---

## 7. Firestore 데이터 모델

### 컬렉션 구조

```
Firestore
├── app_config/
│   ├── version          # 업데이트 정보
│   └── sentence         # Daily Wisdom 문구 배열
└── users/
    └── {userId}/
        ├── daily_logs/
        │   └── {yyyy-MM-dd}/
        │       ├── date: String
        │       ├── records: Map<String, int>   # {"07": 45, "08": 60, ...}
        │       ├── startHour: int
        │       ├── endHour: int
        │       ├── totalActiveMinutes: int
        │       └── efficiencyPct: double
        ├── daily_memos/
        │   └── {yyyy-MM-dd}/
        │       ├── content: String
        │       ├── createdAt: Timestamp
        │       └── updatedAt: Timestamp
        ├── settings/
        │   └── default/
        │       ├── startHour: int       # 기본 기상 시간
        │       ├── endHour: int         # 기본 취침 시간
        │       ├── alarmInterval: int   # 30 or 60 (분)
        │       ├── alarmOn: bool
        │       └── inputType: String    # 'bar' (현재 유일)
        ├── alarm_logs/
        │   └── {auto-id}/
        │       ├── event: String        # 'rescheduled' | 'scheduled' | 'error'
        │       ├── timestamp: Timestamp
        │       ├── platform: String
        │       └── ...extra fields
        └── error_logs/
            └── {auto-id}/
                ├── location: String
                ├── error: String
                ├── stackTrace: String?
                ├── timestamp: Timestamp
                └── platform: String
```

### records 필드 상세
- **키**: `"HH"` 형식 2자리 시간 (e.g. `"07"`, `"23"`)
- **값**: 해당 시간에 유지한 분수 (0~60 정수)

### endHour 인코딩 규칙
| 값 | 의미 |
|---|---|
| `7~24` | 당일 취침 시간 (24 = 자정) |
| `25~` | 다음날 취침 (`N = endHour - 24`시) |
| `endHour < startHour` | 레거시 overnight (raw 저장) |

---

## 8. 알림 시스템

### 알림 텍스트 형식
- **제목**: `중심 유지 App 리마인더`
- **본문**: `오후 3시 정각입니다. 유지 비중을 지금 기록하세요!`

### 채널 정보 (Android)
| 항목 | 값 |
|---|---|
| Channel ID | `joongshim_uji_channel` |
| Channel Name | `중심 유지 알림` |
| Importance | MAX |
| Vibration | 활성화 |
| Sound | 활성화 |

### 권한 요청 흐름
```
앱 시작
  └─ NotificationService.init()
       ├─ Android: POST_NOTIFICATIONS 권한 요청 (Android 13+)
       └─ iOS: alert + badge + sound 권한 요청

알림 예약 시
  └─ rescheduleAlarms()
       ├─ Android: canScheduleExactNotifications() 확인
       │   ├─ true  → AndroidScheduleMode.exactAllowWhileIdle
       │   └─ false → AndroidScheduleMode.inexactAllowWhileIdle (폴백)
       └─ iOS: 항상 exact 모드
```

---

## 9. 테마 & 디자인 시스템

### 색상 팔레트 ([AppTheme](file:///Users/jahyun/developer/joongshim-uji-app/lib/theme/app_theme.dart#3-54))

| 토큰 | 값 | 용도 |
|---|---|---|
| `deepNavy` | `#000000` (검정) | 배경, Scaffold |
| `bgCard` | `#1A1A1A` | 카드 배경 |
| `timelineBg` | `#222222` | 타임라인 배경 |
| `mutedTeal` | `#44AABB` | 주요 액션, 강조 |
| `softIndigo` | `#7A8CC3` | 보조 강조 |
| `activeGreen` | `#34D399` | 유지 비중 수치 |
| `yellowAccent` | `#FACC15` | 오늘 날짜 표시 |
| `textWhite` | `#DDEEFF` | 기본 텍스트 |
| `textGray` | `#8C9EAE` | 보조 텍스트 |

### 폰트
- 기본: `Apple SD Gothic Neo` (iOS 시스템 폰트)
- Android: 시스템 대체 폰트

### 화면 전환
- **메모 화면 진입**: 슬라이드 업 (bottom → top, 350ms easeOutCubic)
- **날짜 전환**: 슬라이드 좌/우 (300ms easeOutCubic)
- **날짜 박스 반짝임**: indigo tween 600ms (날짜 이동 확인용)

---

## 10. 빌드 & 배포

### 빌드 환경

| 항목 | 값 |
|---|---|
| Flutter | 3.41.5 (stable) |
| Dart | 3.11.3 |
| AGP | 8.11.1 |
| Gradle | **8.13** (AGP 8.11.1 최소 요건) |
| Kotlin | 2.1.0 |
| Java | 1.8 (target) |

> ⚠️ **중요**: AGP 8.11.1은 **Gradle 8.13** 이상을 요구합니다.  
> [gradle-wrapper.properties](file:///Users/jahyun/developer/joongshim-uji-app/android/gradle/wrapper/gradle-wrapper.properties)의 `distributionUrl`을 반드시 `gradle-8.13-bin.zip`으로 설정해야 합니다.

### Android 릴리스 빌드
```bash
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

### iOS 릴리스 빌드
```bash
flutter build ios --release
# Xcode에서 Archive → App Store Connect 업로드
```

### 버전 관리 ([pubspec.yaml](file:///Users/jahyun/developer/joongshim-uji-app/pubspec.yaml))
```yaml
version: 1.3.3+20   # semantic_version+build_number
```

### In-App Update 설정 (Firestore)
앱 배포 후 `app_config/version` 문서 업데이트:
```json
{
  "latestVersion": "1.3.3",
  "latestBuildNumber": 20,
  "minVersion": "1.0.0",
  "forceUpdate": false,
  "androidStoreUrl": "market://details?id=com.uji.joongshim",
  "iosStoreUrl": "https://apps.apple.com/app/id6744050393"
}
```

---

## 11. 보안 파일 관리

> 아래 파일들은 Git에 포함되지 않으며 별도 저장소(`joongshim-uji-secure-files/`)에서 관리합니다.

| 파일 | 경로 | 용도 |
|---|---|---|
| [joongshim-uji-release.jks](file:///Users/jahyun/developer/joongshim-uji-app/android/joongshim-uji-release.jks) | `android/` | Android 릴리스 서명 키스토어 |
| [key.properties](file:///Users/jahyun/developer/joongshim-uji-app/android/key.properties) | `android/` | 키스토어 비밀번호, 키 별칭 |
| `google-services.json` | `android/app/` | Android Firebase 설정 |
| `GoogleService-Info.plist` | `ios/Runner/` | iOS Firebase 설정 |
| `Info.plist` | `ios/Runner/` | iOS 앱 설정 (URL scheme 등) |
| `service_account.json` | 루트 | Firebase Admin SDK 서비스 계정 |
| `service_account_new.json` | 루트 | 신규 서비스 계정 (교체용) |

---

## 변경 이력 (최근)

| 버전 | 주요 변경 사항 |
|---|---|
| v1.3.3+20 | 홈 화면 스와이프 날짜 이동 제거. 메모장 스와이프를 메모 있는 날만 이동하도록 변경. 날짜 이동 시 반짝임 효과 추가. Daily Wisdom 배너 높이 개선. Gradle 8.13 업그레이드. |
| v1.3.x | Daily Wisdom 배너, 캘린더 메모 틴트, 스와이프 날짜 이동, In-App Update |
| v1.2.x | Apple 로그인, 계정 삭제, 개인정보처리방침 뷰어 |
| v1.1.x | Android 알림 정밀 알람 권한, 자정 초과 모드 지원 |
| v1.0.x | 초기 릴리스: 에너지 기록, 통계, 설정, 알림 |
