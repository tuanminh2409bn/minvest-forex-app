import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart';

class BankTransferScreen extends StatefulWidget {
  final double amountUSD;
  final String orderInfo;

  const BankTransferScreen({
    super.key,
    required this.amountUSD,
    required this.orderInfo,
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  late final WebViewController _controller;
  String? _vnpayUrl;
  bool _isLoading = true;
  String _loadingMessage = "Đang tạo đơn hàng...";

  @override
  void initState() {
    super.initState();
    _createVnpayOrder();
  }

  Future<void> _createVnpayOrder() async {
    setState(() { _isLoading = true; });

    try {
      FirebaseFunctions functions = FirebaseFunctions.instance;
      final HttpsCallable callable = functions.httpsCallable('createVnpayOrder');
      final HttpsCallableResult result = await callable.call({
        'amount': widget.amountUSD,
        'orderInfo': widget.orderInfo,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null) {
        setState(() {
          _vnpayUrl = paymentUrl;
          _initializeWebView();
          _isLoading = false;
        });
      } else {
        throw Exception("URL thanh toán không hợp lệ.");
      }
    } catch (e) {
      print("Lỗi khi tạo đơn hàng VNPay: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
    // === SỬA LỖI: Cung cấp một User-Agent Android chuẩn ===
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            const String returnUrl = 'https://sandbox.vnpayment.vn/tryitnow/Home/VnPayReturn';

            if (request.url.startsWith(returnUrl)) {
              final uri = Uri.parse(request.url);
              final responseCode = uri.queryParameters['vnp_ResponseCode'];

              if (responseCode == '00') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UpgradeSuccessScreen()),
                      (route) => route.isFirst,
                );
              } else {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Giao dịch đã bị hủy hoặc thất bại.')),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_vnpayUrl!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNPAY PAYMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF151a2e),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage),
          ],
        ),
      )
          : _vnpayUrl != null
          ? WebViewWidget(controller: _controller)
          : const Center(
        child: Text("Không thể tạo link thanh toán.\nVui lòng thử lại.", textAlign: TextAlign.center),
      ),
    );
  }
}