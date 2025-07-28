import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart';
import 'package:vnpay_flutter/vnpay_flutter.dart';

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
  bool _isLoading = true;
  String _loadingMessage = "Đang tạo đơn hàng...";

  @override
  void initState() {
    super.initState();
    // Gọi hàm tạo đơn hàng ngay khi màn hình được mở
    _createAndShowVnpayOrder();
  }

  Future<void> _createAndShowVnpayOrder() async {
    setState(() { _isLoading = true; });

    try {
      // 1. Gọi Firebase Function để lấy URL thanh toán an toàn
      FirebaseFunctions functions = FirebaseFunctions.instance;
      final HttpsCallable callable = functions.httpsCallable('createVnpayOrder');
      final HttpsCallableResult result = await callable.call({
        'amount': widget.amountUSD,
        'orderInfo': widget.orderInfo,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null && paymentUrl is String) {
        // Ẩn màn hình loading trước khi mở cổng thanh toán
        setState(() { _isLoading = false; });

        // 2. Dùng thư viện vnpay_flutter để hiển thị cổng thanh toán
        VNPAYFlutter.instance.show(
          context: context,
          paymentUrl: paymentUrl,
          onPaymentSuccess: (params) {
            // Thanh toán thành công!
            // Backend (IPN Listener) sẽ xử lý việc nâng cấp.
            // Điều hướng người dùng đến màn hình thành công.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UpgradeSuccessScreen()),
                  (route) => route.isFirst,
            );
          },
          onPaymentError: (params) {
            // Thanh toán thất bại hoặc bị hủy
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Giao dịch đã bị hủy hoặc thất bại.')),
            );
          },
        );
      } else {
        throw Exception("URL thanh toán không hợp lệ.");
      }
    } catch (e) {
      print("Lỗi khi tạo đơn hàng VNPay: $e");
      setState(() {
        _isLoading = false;
        _loadingMessage = "Không thể tạo đơn hàng. Vui lòng thử lại.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VNPAY PAYMENT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF151a2e),
        centerTitle: true,
      ),
      // Chỉ hiển thị màn hình chờ, vì cổng thanh toán sẽ hiện lên trên
      body: Center(
        child: _isLoading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingMessage),
          ],
        )
        // Nếu có lỗi, hiển thị thông báo
            : Text(
          _loadingMessage,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}