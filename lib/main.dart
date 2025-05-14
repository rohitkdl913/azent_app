// import 'package:flutter/material.dart';
// import 'package:lottie/lottie.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: WebApp(),
//     );
//   }
// }

// class WebApp extends StatefulWidget {
//   const WebApp({super.key});

//   @override
//   State<WebApp> createState() => _WebAppState();
// }

// class _WebAppState extends State<WebApp> {
//   late final WebViewController _controller;
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setUserAgent("random")
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageFinished: (_) {
//             setState(() {
//               isLoading = false;
//             });
//           },
//           onNavigationRequest: (request) async {
//             if (request.url.startsWith('http') ||
//                 request.url.startsWith('https')) {
//               return NavigationDecision.navigate;
//             } else {
//               // Handle custom schemes (like intent://, fb://, etc.)
//               if (await canLaunchUrl(Uri.parse(request.url))) {
//                 await launchUrl(Uri.parse(request.url));
//               }
//               return NavigationDecision.prevent;
//             }
//           },
//         ),
//       )
//       ..loadRequest(
//           Uri.parse('https://www.azent.io/')); // Change to your website URL
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//             if (!isLoading) WebViewWidget(controller: _controller),
//             if (isLoading)
//               Center(
//                 child: Lottie.asset("assets/animation.json"),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }





import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azent WebView',
      debugShowCheckedModeBanner: false,
      home: const WebApp(),
    );
  }
}

class WebApp extends StatefulWidget {
  const WebApp({super.key});
  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp> {
  late final WebViewController _controller;
  bool isLoading = true;
  final String homeUrl = 'https://www.azent.io/';
  final String postLoginIndicator = '/dashboard';        // your post-login URL path
  final String oauthCallbackPrefix = '/auth/callback';   // adjust to your OAuth callback

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("random")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            setState(() => isLoading = false);

            // If we land on your dashboard or OAuth callback, save all cookies
            if (url.contains(postLoginIndicator) ||
                url.contains(oauthCallbackPrefix)) {
              final raw = await _controller
                  .runJavaScriptReturningResult('document.cookie') as String;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('session_cookies', raw);
              debugPrint('[Azent] Saved cookies ⇒ $raw');
            }
          },
          onNavigationRequest: (request) async {
            final u = request.url;
            // Allow HTTP(S) to proceed in-WebView
            if (u.startsWith('http://') || u.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            // Otherwise, try to launch natively (e.g. OAuth intents)
            final uri = Uri.parse(u);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    _restoreCookies().then((_) {
      _controller.loadRequest(Uri.parse(homeUrl));
    });
  }

  /// Reads saved cookies from SharedPreferences and injects them
  Future<void> _restoreCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('session_cookies') ?? '';
    if (saved.isEmpty) return;

    for (var pair in saved.split(';')) {
      final parts = pair.trim().split('=');
      if (parts.length == 2) {
        final name = parts[0];
        final value = parts[1];
        
        await WebViewCookieManager().setCookie(
          WebViewCookie(
            name: name,
            value: value,
            domain: "www.azent.io",  // adjust if needed (no www, subdomain, etc.)
            path: "/",
          ),
        );
      }
    }
    debugPrint('[Azent] Re-injected ${saved.split(';').length} cookies');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              Center(child: Lottie.asset("assets/animation.json")),
          ],
        ),
      ),
    );
  }
}
