import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Squid Jump',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GameWebView(),
    );
  }
}

class GameWebView extends StatefulWidget {
  const GameWebView({super.key});

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      // Load HTML content
      final htmlContent = await rootBundle.loadString('lib/game.html');

      // Initialize the WebView platform
      late final PlatformWebViewControllerCreationParams params;
      
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final WebViewController controller =
          WebViewController.fromPlatformCreationParams(params);

      // Get the base URL based on platform
      String baseUrl = 'file:///android_asset/';
      
      try {
        if (Platform.isIOS || Platform.isMacOS) {
          final appDocDir = await getApplicationDocumentsDirectory();
          baseUrl = 'file://${appDocDir.path}/';
        } else if (Platform.isWindows || Platform.isLinux) {
          baseUrl = 'file:///';
        } else if (Platform.isAndroid) {
          baseUrl = 'file:///android_asset/';
        }
      } catch (e) {
        debugPrint('Platform detection error: $e');
        baseUrl = 'file:///';
      }

      try {
        controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                debugPrint('WebView is loading (progress : $progress%)');
              },
              onPageStarted: (String url) {
                debugPrint('Page started loading: $url');
              },
              onPageFinished: (String url) {
                debugPrint('Page finished loading: $url');
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
                ''');
              },
              onNavigationRequest: (NavigationRequest request) {
                debugPrint('Navigation to: ${request.url}');
                return NavigationDecision.navigate;
              },
              onUrlChange: (UrlChange change) {
                debugPrint('url change to ${change.url}');
              },
            ),
          );
      } catch (e) {
        debugPrint('WebView configuration error: $e');
      }

      try {
        // Set Android-specific settings
        if (controller.platform is AndroidWebViewController) {
          AndroidWebViewController.enableDebugging(true);
          (controller.platform as AndroidWebViewController)
              .setMediaPlaybackRequiresUserGesture(false);
        }
      } catch (e) {
        debugPrint('Android setup error: $e');
      }

      try {
        controller.loadHtmlString(htmlContent, baseUrl: baseUrl);
      } catch (e) {
        debugPrint('Error loading HTML: $e');
      }

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      debugPrint('Error initializing WebView: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: WebViewWidget(controller: _controller!),
    );
  }
}
