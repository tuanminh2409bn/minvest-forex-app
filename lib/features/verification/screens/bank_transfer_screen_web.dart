import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/screens/upgrade_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

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
  String _loadingMessage = ""; // Sẽ được cập nhật trong initState
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _loadingMessage = AppLocalizations.of(context)!.creatingOrderWait;
      });
      _createAndLaunchVnpayOrder();
    });
  }

  Future<void> _createAndLaunchVnpayOrder() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final HttpsCallable callable = functions.httpsCallable('createVnpayOrder');

      String productId;
      if (widget.amountUSD == 78) {
        productId = 'elite_1_month_vnpay';
      } else if (widget.amountUSD == 460) {
        productId = 'elite_12_months_vnpay';
      } else {
        throw Exception('Invalid amount: ${widget.amountUSD}');
      }

      final HttpsCallableResult result = await callable.call({
        'productId': productId,
        'orderInfo': widget.orderInfo,
      });

      final paymentUrl = result.data['paymentUrl'];

      if (paymentUrl != null) {
        final Uri uri = Uri.parse(paymentUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception(l10n.couldNotLaunch(paymentUrl));
        }
        if (mounted) {
          // Chuyển đến màn hình thành công sau khi mở link
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UpgradeSuccessScreen()),
                (route) => route.isFirst,
          );
        }
      } else {
        throw Exception(l10n.invalidPaymentUrl);
      }
    } on FirebaseFunctionsException catch (e) {
      print("Lỗi Firebase Functions khi tạo đơn hàng VNPay: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = l10n.serverErrorRetry(e.message ?? 'Unknown error');
        });
      }
    } catch (e) {
      print("Lỗi ngoại lệ khi tạo đơn hàng VNPay: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = l10n.cannotCreatePaymentLink;
        });
      }
    }
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
                child: Text(l10n.retry),
              )
            ],
          ),
        )
            : Text(l10n.redirectingToPayment),
      ),
    );
  }
}
