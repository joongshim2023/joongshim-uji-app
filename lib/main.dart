import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/trend_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'firebase_options.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().init();
  } catch(e) {
    print('Notification Engine Error: $e');
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // google_sign_in 7.x: Android/iOS에서만 초기화 (웹에서는 불필요)
  // serverClientId = google-services.json의 client_type:3 (Web Client ID)
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: '880648187658-bfejjnap1bn8rq8usu7e5l2td7g1g9mc.apps.googleusercontent.com',
    );
  }
  runApp(const JoongshimUjiApp());
}


class JoongshimUjiApp extends StatelessWidget {
  const JoongshimUjiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '중심 유지 App',
      theme: AppTheme.themeData,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const MainNavigator();
          }
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({Key? key}) : super(key: key);

  @override
  _MainNavigatorState createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TrendScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 앱 시작 후 짧은 딜레이 후 업데이트 체크 (UI 렌더 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), _checkForUpdate);
    });
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateService().checkForUpdate();
    if (!result.hasUpdate || !mounted) return;

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      barrierDismissible: !result.forceUpdate, // 강제 업데이트면 바깥 탭 닫기 불가
      builder: (_) => PopScope(
        canPop: !result.forceUpdate, // 강제 업데이트면 뒤로 가기 불가
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A2035),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_outlined, color: Color(0xFF4ECDC4), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.forceUpdate ? '업데이트 필요' : '새 버전 출시!',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'v${result.latestVersion}',
                      style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Text(
            result.message ?? '새로운 버전이 출시되었습니다. 업데이트 후 더 좋은 경험을 누려보세요.',
            style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 14, height: 1.6),
          ),
          actions: [
            if (!result.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('나중에', style: TextStyle(color: Color(0xFF9AA3B2))),
              ),
            TextButton(
              onPressed: () async {
                final url = Uri.parse(result.storeUrl ?? '');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '업데이트',
                  style: TextStyle(color: Color(0xFF0D1421), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), activeIcon: Icon(Icons.insights), label: '통계'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
