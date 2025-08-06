import 'package:flutter/material.dart';
// WebView không còn được sử dụng nên thư viện này có thể bị mờ đi
// import 'package:webview_flutter/webview_flutter.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  // ▼▼▼ TẠM THỜI VÔ HIỆU HÓA WEBVIEW CONTROLLER ▼▼▼
  // late final WebViewController _controller;
  // bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    /*
    // --- Toàn bộ code khởi tạo WebView đã được comment lại ---
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://s.tradingview.com/widgetembed/?frameElementId=tradingview_76d87&symbol=FX%3AEURUSD&interval=D&hidesidetoolbar=0&hidetoptoolbar=1&symboledit=1&saveimage=1&toolbarbg=F1F3F6&studies=%5B%5D&theme=dark&style=1&timezone=Etc%2FUTC&studies_overrides=%7B%7D&overrides=%7B%7D&enabled_features=%5B%5D&disabled_features=%5B%5D&locale=en&utm_source=www.tradingview.com&utm_medium=widget_new&utm_campaign=chart&utm_term=FX%3AEURUSD'));
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'MARKET CHART',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      // ▼▼▼ THAY THẾ WEBVIEW BẰNG MỘT PLACEHOLDER ĐƠN GIẢN ▼▼▼
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 80,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Chart is temporarily disabled',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      ),
      /*
      // --- Code WebView cũ đã được comment lại ---
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0D1117),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      */
    );
  }
}