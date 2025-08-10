import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _loadingMessage = "Đang tạo đơn hàng, vui lòng chờ...";
  String? _error;

  @override
  void initState() {
    super.initState();
    _createAndLaunchVnpayOrder();
  }

  Future<void> _createAndLaunchVnpayOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1'); // Thêm region cho an toàn
      final HttpsCallable callable = functions.httpsCallable('createVnpayOrder');

      final HttpsCallableResult result = await callable.call({
        'amount': widget.amountUSD,
        'orderInfo': widget.orderInfo,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null) {
        final Uri uri = Uri.parse(paymentUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $paymentUrl');
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception("URL thanh toán không hợp lệ nhận từ server.");
      }
    } on FirebaseFunctionsException catch (e) {
      print("Lỗi Firebase Functions khi tạo đơn hàng VNPay: ${e.code} - ${e.message}");
      setState(() {
        _isLoading = false;
        _error = "Lỗi từ server: ${e.message}. Vui lòng thử lại.";
      });
    } catch (e) {
      print("Lỗi ngoại lệ khi tạo đơn hàng VNPay: $e");
      setState(() {
        _isLoading = false;
        _error = "Không thể tạo link thanh toán. Vui lòng kiểm tra kết nối và thử lại.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNPAY PAYMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF151a2e),
        centerTitle: true,
      ),
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
            : _error != null
            ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createAndLaunchVnpayOrder,
                child: const Text('Thử lại'),
              )
            ],
          ),
        )
            : const Text("Đang chuyển hướng đến trang thanh toán..."),
      ),
    );
  }
}
