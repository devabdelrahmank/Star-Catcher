import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({Key? key}) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasConnection = true;
  Timer? _connectionCheckTimer;
  final String _url = 'https://starcatcher.online/';

  // إضافة متغيرات للتعامل مع النقر المزدوج
  DateTime? _lastBackPressTime;
  bool _doubleBackToExitPressed = false;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _initWebView();

    // إنشاء مؤقت لفحص الاتصال كل 5 ثوانٍ
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkInternetConnection();
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          if (!_hasConnection) {
            _hasConnection = true;
            // إعادة تحميل الصفحة عند عودة الاتصال
            _controller.reload();
          } else {
            _hasConnection = true;
          }
        });
      }
    } on SocketException catch (_) {
      setState(() {
        _hasConnection = false;
      });
    }
  }

  void _initWebView() {
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                setState(() {
                  _isLoading = true;
                });
              },
              onPageFinished: (String url) {
                setState(() {
                  _isLoading = false;
                });
              },
              onWebResourceError: (WebResourceError error) {
                SnackBar(content: Text(error.description));
                setState(() {
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadRequest(Uri.parse(_url));
  }

  void _reloadWebView() {
    _checkInternetConnection();
    if (_hasConnection) {
      _controller.reload();
    }
  }

  Future<bool> _handlePopScope() async {
    // التحقق من النقر المزدوج للخروج
    final DateTime now = DateTime.now();

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 1)) {
      // تخزين وقت النقرة الأولى
      _lastBackPressTime = now;

      // إظهار رسالة توجيه للمستخدم
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('اضغط مرة أخرى للخروج من التطبيق'),
      //     duration: Duration(seconds: 2),
      //     backgroundColor: Colors.red,
      //   ),
      // );

      // التحقق إذا كان بإمكان WebView الرجوع للخلف
      if (await _controller.canGoBack()) {
        _controller.goBack();
        return false;
      } else {
        // العودة إلى الصفحة الرئيسية إذا لم يكن هناك صفحات للرجوع
        _controller.loadRequest(Uri.parse(_url));
        return false;
      }
    } else {
      // النقرة الثانية خلال ثانيتين - الخروج من التطبيق
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _doubleBackToExitPressed,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _handlePopScope();

        if (shouldPop) {
          setState(() {
            _doubleBackToExitPressed = true;
          });

          // قم بمحاولة أخرى للخروج
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // حالة وجود اتصال بالإنترنت
            if (_hasConnection) WebViewWidget(controller: _controller),

            // حالة عدم وجود اتصال بالإنترنت
            if (!_hasConnection)
              Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.signal_wifi_off,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No internet connection available !!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _reloadWebView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_isLoading && _hasConnection)
              const Center(child: CircularProgressIndicator(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
