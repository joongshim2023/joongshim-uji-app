import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

class AppStrings {
  static final Map<String, String> enStrings = {
    // login_screen
    '중심 유지': "Let's Feel Joongshim",
    '중심 유지 App': "Let's Feel Joongshim",
    '이메일': 'Email',
    '비밀번호 (알파벳+숫자 6자 이상)': 'Password (Alphanumeric 6+ chars)',
    '이메일 저장': 'Remember Email ID',
    '로그인': 'Log In',
    '회원가입': 'Sign Up',
    '비밀번호 찾기': 'Find Password',
    '처음이신가요? 회원가입': 'Register',
    '이미 계정이 있나요? 로그인': 'Have an account? Log In',
    'Google 계정으로 로그인': 'Google Login',
    'Apple 계정으로 로그인': 'Sign in with Apple',
    '입력 오류': 'Input Error',
    '이메일과 비밀번호를 모두 입력해주세요.': 'Please enter both email and password.',
    '비밀번호 오류': 'Password Error',
    '비밀번호는 영문자와 숫자를 모두 포함하여 6자 이상이어야 합니다.': 'Password must be at least 6 characters including letters and numbers.',
    '로그인 실패': 'Login Failed',
    '회원가입 실패': 'Sign Up Failed',
    '이메일 필요': 'Email Required',
    '위쪽 이메일 입력칸에 이메일을 먼저 입력해주세요.': 'Please enter your email above first.',
    '이메일 발송 완료': 'Email Sent',
    '비밀번호 재설정 링크가 ': 'A password reset link has been sent to ',
    ' 으로 발송되었습니다.\n메일함을 확인해주세요.': '.\nPlease check your inbox.',
    '발송 실패': 'Failed to Send',
    '오류가 발생했습니다.\n': 'An error occurred.\n',

    // main_navigator
    '홈': 'Home',
    '유지': 'Home',
    '메모': 'Memo',
    '통계': 'Trend',
    '설정': 'Settings',

    // settings_screen
    '확인': 'OK',
    '설정 타이틀': 'Setting',
    '나의 리듬 (기본값)': 'My Lifecycle (default)',
    '기본 기상 시간': 'Default Wake Time',
    '기본 취침 시간': 'Default Sleep Time',
    '알림 시스템': 'Alarm System',
    '알림 켜기': 'Enable Notifications',
    '알람 간격': 'Alarm Interval',
    '계정 및 데이터': 'Account & Data',
    '프로필': 'Profile',
    '기록 내보내기 (CSV)': 'Export Records (CSV)',
    '메모 내보내기 (TXT)': 'Export Memo (TXT)',
    '개인정보처리방침': 'Privacy Policy',
    '로그아웃': 'Logout',
    '버전 정보': 'Version',
    '기상 시간 (기본값)': 'Wake Time (default)',
    '취침 시간 (기본값)': 'Sleep Time (default)',
    '취소': 'Cancel',
    '저장': 'Save',
    '알림 주기 선택': 'Select Alarm Interval',
    '30분마다 알림': 'Every 30 mins',
    '60분마다 알림': 'Every 60 mins',
    '현재 연동된 이메일 계정': 'Currently linked email account',
    '알 수 없는 계정': 'Unknown account',
    '이메일로 비밀번호 재설정 링크 받기': 'Get password reset link via email',
    '계정 삭제': 'Delete Account',
    '언어 (Language)': 'Language',
    '인증 실패': 'Authentication Failed',
    '비밀번호가 올바르지 않습니다. 다시 확인해주세요.': 'Incorrect password. Please try again.',
    '재인증 실패': 'Re-authentication Failed',
    '인증 중 오류가 발생했습니다. 다시 시도해주세요.': 'An error occurred during authentication. Please try again.',
    '재로그인 필요': 'Re-login Required',
    '보안을 위해 앱을 재시작하여 다시 로그인 후 계정 삭제를 시도해주세요.': 'For security, please restart the app, log in again, and then try deleting your account.',
    '삭제 실패': 'Deletion Failed',
    '오류가 발생했습니다.': 'An error occurred.',
    '내보내기 실패': 'Export Failed',
    '파일 생성 중 오류가 발생했습니다.': 'An error occurred while creating the file.',
    '메모 내보내기 실패': 'Memo Export Failed',
    '로그아웃 실패': 'Logout Failed',
    '메모 내보내기 범위 선택': 'Select Memo Export Range',
    '기록 내보내기 범위 선택': 'Select Record Export Range',
    '추출할 메모의 시작 날짜와 종료 날짜를 선택하세요.': 'Select the start and end dates for the memos to export.',
    '추출할 데이터의 시작 날짜와 종료 날짜를 선택하세요.': 'Select the start and end dates for the records to export.',
    '정밀 알람 권한 필요': 'Exact Alarm Permission Required',
    '30분/60분 간격으로 정확히 알림을 받으려면 알람 및 리마인더 권한이 필요합니다.': 'Exact alarm permission is required to receive notifications at exact 30/60 minute intervals.',
    '나중에': 'Later',
    '설정으로 이동': 'Go to Settings',

    // trend_screen
    '유지 통계': 'Trend Analysis',
    '캘린더': 'Calendar',
    '그래프': 'Graph',
    '주간 동향': 'Weekly Trend',
    '일': 'Sun', '월': 'Mon', '화': 'Tue', '수': 'Wed', '목': 'Thu', '금': 'Fri', '토': 'Sat',
    '메모가 있는 날은 배경색이 다릅니다.\n날짜를 클릭하면 기록을 볼 수 있습니다.': 'Dates with memos have a different background.\nTap a date to view its records.',
    '편집': 'Edit',
    '삭제': 'Delete',
    '기록 또는 메모를 삭제할 날짜를 선택하세요': 'Select a date to delete records or memos',
    '메모 삭제': 'Delete Memo',
    '기록 삭제': 'Delete Record',
    '삭제 경고': 'Delete Warning',
    '선택한 ': 'Are you sure you want to delete ',
    '개의 날짜에 대한 ': ' for the ',
    '를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.': ' selected dates?\nThis action cannot be undone.',
    '확인 후 삭제': 'Confirm and Delete',
    '로그인이 필요합니다.': 'Login is required.',

    // home_screen
    '중심 유지 (홈 타이틀)': 'Feel Joongshim Energy',
    '오늘': 'Today',
    '선택됨': 'selected',
    '활동 시간 관리': 'Activity Time Management',
    '총 목표 시간': 'Total Goal Time',
    '시간': 'h',
    '분': 'm',
    '유지 시간 산정 중...': 'Calculating...',
    '총 유지시간': 'Active Time',
    '유지비중': 'Ratio',
    '활동 시간': 'Active Time',

    // home_screen - time settings popup
    '활동 시간 설정': 'Active Hours Setting',
    '기상 시간': 'Wake Time',
    '취침 시간': 'Sleep Time',
    '다음날 기상시간': 'next day wake time',
    '까지 자정 초과 취침 가능합니다.': ') Sleep time is available up to next day',
    '다음날 새벽 ': 'Set to ',
    '시까지로 설정됩니다.': ' am next day',
    '저장하기': 'Save',

    // memo_screen
    '이 날의 메모를 남겨보세요': 'Leave a note for this day.',
    '메모 저장': 'Save Memo',
    '저장됨': 'Saved',

    // timeline
    '자정': 'AM 0',
    '다음날': 'Next',
  };

  static String tr(BuildContext context, String koString) {
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: true).currentLanguage;
      if (lang == 'en') {
        return enStrings[koString] ?? koString;
      }
    } catch (_) {
      // In case we don't have Provider context (e.g. init state)
    }
    return koString;
  }
}
