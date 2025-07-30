import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Cấu hình WebView Controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117)) // Màu nền tối
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
    // Đây là URL của TradingView Widget. Chúng ta sẽ tùy chỉnh nó sau.
      ..loadRequest(Uri.parse('https://s.tradingview.com/widgetembed/?frameElementId=tradingview_76d87&symbol=FX%3AEURUSD&interval=D&hidesidetoolbar=0&hidetoptoolbar=1&symboledit=1&saveimage=1&toolbarbg=F1F3F6&studies=%5B%5D&theme=dark&style=1&timezone=Etc%2FUTC&studies_overrides=%7B%7D&overrides=%7B%7D&enabled_features=%5B%5D&disabled_features=%5B%5D&locale=en&utm_source=www.tradingview.com&utm_medium=widget_new&utm_campaign=chart&utm_term=FX%3AEURUSD'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Đặt màu nền tối cho toàn màn hình
      appBar: AppBar(
        title: const Text(
          'MARKET CHART',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Ẩn nút back
      ),
      body: Stack(
        children: [
          // WebView sẽ nằm ở lớp dưới
          WebViewWidget(controller: _controller),

          // Lớp loading che phủ lên trên
          if (_isLoading)
            Container(
              color: const Color(0xFF0D1117), // Che đi WebView trong lúc tải
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}