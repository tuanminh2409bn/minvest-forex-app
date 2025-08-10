import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart'; // Đảm bảo bạn đã có màn hình này

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
  /// Khởi tạo HttpsCallable một lần để tái sử dụng.
  /// Đây là điểm sửa lỗi quan trọng nhất, chỉ định đúng region 'asia-southeast1'.
  final HttpsCallable _createVnpayOrderCallable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .httpsCallable('createVnpayOrder');

  late final WebViewController _controller;
  String? _vnpayUrl;
  bool _isLoading = true;
  String _loadingMessage = "Đang tạo đơn hàng, vui lòng chờ...";

  @override
  void initState() {
    super.initState();
    // Bắt đầu quá trình tạo đơn hàng ngay khi màn hình được khởi tạo.
    _executeVnpayOrderCreation();
  }

  /// Hàm thực thi việc gọi Cloud Function để tạo link thanh toán.
  Future<void> _executeVnpayOrderCreation() async {
    // Đảm bảo widget vẫn còn trên cây giao diện trước khi cập nhật state.
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Gọi Cloud Function với các tham số cần thiết.
      final result = await _createVnpayOrderCallable.call<Map<String, dynamic>>({
        'amount': widget.amountUSD,
        'orderInfo': widget.orderInfo,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null && mounted) {
        setState(() {
          _vnpayUrl = paymentUrl;
          _initializeWebView(); // Chỉ khởi tạo WebView sau khi đã có URL.
          _isLoading = false;
        });
      } else {
        // Ném lỗi nếu server trả về kết quả nhưng không có URL.
        throw Exception("Server không trả về URL thanh toán hợp lệ.");
      }
    } on FirebaseFunctionsException catch (e) {
      // Ghi log lỗi cụ thể từ Firebase để dễ dàng gỡ lỗi.
      debugPrint("Lỗi Firebase Functions: [${e.code}] ${e.message}");
      if (mounted) {
        setState(() {
          _loadingMessage = "Lỗi: ${e.message}";
          _isLoading = false;
        });
      }
    } catch (e) {
      // Bắt các lỗi khác (ví dụ: lỗi mạng, lỗi phân tích dữ liệu).
      debugPrint("Lỗi khi tạo đơn hàng VNPay: $e");
      if (mounted) {
        setState(() {
          _loadingMessage = "Không thể kết nối đến máy chủ. Vui lòng thử lại.";
          _isLoading = false;
        });
      }
    }
  }

  /// Khởi tạo và cấu hình WebView sau khi đã nhận được URL thanh toán.
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
    // Giả lập User-Agent của một thiết bị di động để đảm bảo tương thích.
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // URL trả về của VNPAY sau khi người dùng hoàn tất thanh toán.
            const String returnUrl = 'https://sandbox.vnpayment.vn/tryitnow/Home/VnPayReturn';

            // Kiểm tra nếu URL hiện tại là URL trả về.
            if (request.url.startsWith(returnUrl)) {
              final uri = Uri.parse(request.url);
              final responseCode = uri.queryParameters['vnp_ResponseCode'];

              // Giao dịch thành công.
              if (responseCode == '00') {
                // Chuyển đến màn hình thành công và xóa tất cả các màn hình trước đó.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UpgradeSuccessScreen()),
                      (route) => route.isFirst,
                );
              } else {
                // Giao dịch thất bại hoặc bị hủy.
                Navigator.of(context).pop(); // Quay lại màn hình trước đó.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Giao dịch đã bị hủy hoặc thất bại.')),
                );
              }
              // Ngăn WebView điều hướng đến trang trả về.
              return NavigationDecision.prevent;
            }
            // Cho phép WebView điều hướng đến các trang khác (trang thanh toán VNPAY).
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
        title: const Text('THANH TOÁN VNPAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF151a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_loadingMessage),
          ],
        ),
      )
          : _vnpayUrl != null
          ? WebViewWidget(controller: _controller)
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadingMessage, // Hiển thị thông báo lỗi chi tiết hơn
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _executeVnpayOrderCreation,
                child: const Text('Thử lại'),
              )
            ],
          ),
        ),
      ),
    );
  }
}