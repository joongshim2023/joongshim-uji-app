import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const _url =
      'https://jh-pages.notion.site/App-328baf99869180429bedd807255a6145';

  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoading = true),
            onPageFinished: (_) => setState(() => _isLoading = false),
          ),
        )
        ..loadRequest(Uri.parse(_url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textWhite,
        title: const Text('개인정보처리방침',
            style: TextStyle(color: AppTheme.textWhite, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: kIsWeb
          // 웹에서는 WebView 사용 불가 → 안내 메시지
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.policy_outlined,
                      color: AppTheme.mutedTeal, size: 48),
                  const SizedBox(height: 16),
                  const Text('아래 링크를 브라우저에서 열어주세요.',
                      style: TextStyle(color: AppTheme.textGray)),
                  const SizedBox(height: 12),
                  SelectableText(
                    _url,
                    style: const TextStyle(
                        color: AppTheme.mutedTeal,
                        fontSize: 13,
                        decoration: TextDecoration.underline),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.mutedTeal)),
              ],
            ),
    );
  }
}
