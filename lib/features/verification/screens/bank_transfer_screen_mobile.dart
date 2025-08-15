import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class BankTransferScreen extends StatefulWidget {
  final double amountUSD;
  final String orderInfo;
  final String productId; // <<< THÊM VÀO

  const BankTransferScreen({
    super.key,
    required this.amountUSD,
    required this.orderInfo,
    required this.productId, // <<< THÊM VÀO
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final HttpsCallable _createVnpayOrderCallable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .httpsCallable('createVnpayOrder');

  late final WebViewController _controller;
  String? _vnpayUrl;
  bool _isLoading = true;
  String _loadingMessage = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _loadingMessage = AppLocalizations.of(context)!.creatingOrderWait;
        });
        _executeVnpayOrderCreation();
      }
    });
  }

  Future<void> _executeVnpayOrderCreation() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() { _isLoading = true; });

    try {
      // <<< SỬA ĐỔI: Thêm productId vào payload gửi đi
      final result = await _createVnpayOrderCallable.call<Map<String, dynamic>>({
        'amount': widget.amountUSD,
        'orderInfo': widget.orderInfo,
        'productId': widget.productId,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null && mounted) {
        setState(() {
          _vnpayUrl = paymentUrl;
          _initializeWebView();
          _isLoading = false;
        });
      } else {
        throw Exception(l10n.invalidPaymentUrl);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Lỗi Firebase Functions: [${e.code}] ${e.message}");
      if (mounted) {
        setState(() {
          _loadingMessage = l10n.errorWithMessage(e.message ?? 'Unknown error');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi tạo đơn hàng VNPay: $e");
      if (mounted) {
        setState(() {
          _loadingMessage = l10n.cannotConnectToServer;
          _isLoading = false;
        });
      }
    }
  }

  void _initializeWebView() {
    final l10n = AppLocalizations.of(context)!;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Thay bằng Return URL thực tế của bạn nếu khác
            const String returnUrl = 'https://minvest.vn/payment-result';

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
                  SnackBar(content: Text(l10n.transactionCancelledOrFailed)),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vnpayPaymentTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                _loadingMessage.isNotEmpty ? _loadingMessage : l10n.cannotCreatePaymentLink,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _executeVnpayOrderCreation,
                child: Text(l10n.retry),
              )
            ],
          ),
        ),
      ),
    );
  }
}