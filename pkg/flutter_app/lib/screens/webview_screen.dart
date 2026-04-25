import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/app_theme.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  bool _hasError = false;
  String? _errorMessage;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onProgress: (progress) {
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = error.description;
            });
          },
          onNavigationRequest: (request) {
            // Allow all navigation (adjust if you want to restrict)
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          _handleJsBridgeMessage(msg.message);
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleJsBridgeMessage(String message) {
    // Handle messages from the HTML page's JavaScript
    // e.g. window.FlutterBridge.postMessage('{"action":"close"}')
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('JS Bridge: $message'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _showAppBar
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isLoading)
                    Text(
                      'Loading... $_loadingProgress%',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6)),
                    ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await _controller.canGoBack()) {
                    _controller.goBack();
                  } else {
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
              actions: [
                // Toggle appbar visibility
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () =>
                      setState(() => _showAppBar = false),
                  tooltip: 'Fullscreen',
                ),
                // Refresh
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reload,
                  tooltip: 'Reload',
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'back':
                        if (await _controller.canGoBack()) {
                          _controller.goBack();
                        }
                        break;
                      case 'forward':
                        if (await _controller.canGoForward()) {
                          _controller.goForward();
                        }
                        break;
                      case 'copyUrl':
                        final url = await _controller.currentUrl();
                        if (mounted && url != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(url)),
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'back',
                        child: Row(children: [
                          Icon(Icons.arrow_back, size: 18),
                          SizedBox(width: 8),
                          Text('Go Back'),
                        ])),
                    PopupMenuItem(
                        value: 'forward',
                        child: Row(children: [
                          Icon(Icons.arrow_forward, size: 18),
                          SizedBox(width: 8),
                          Text('Go Forward'),
                        ])),
                    PopupMenuItem(
                        value: 'copyUrl',
                        child: Row(children: [
                          Icon(Icons.link, size: 18),
                          SizedBox(width: 8),
                          Text('Copy URL'),
                        ])),
                  ],
                ),
              ],
              bottom: _isLoading
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(3),
                      child: LinearProgressIndicator(
                        value: _loadingProgress / 100,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accent),
                        minHeight: 3,
                      ),
                    )
                  : null,
            )
          : null,

      body: Stack(
        children: [
          // ── WebView ────────────────────────────────────────────────────
          if (!_hasError)
            WebViewWidget(controller: _controller),

          // ── Error state ────────────────────────────────────────────────
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_outlined,
                        size: 64, color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load page',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Floating show-appbar button (fullscreen mode) ──────────────
          if (!_showAppBar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _showAppBar = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_exit,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Exit fullscreen',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
