import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/models/payment_method.dart';
import 'package:minvest_forex_app/features/verification/screens/bank_transfer_screen.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class PackageScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  const PackageScreen({super.key, required this.paymentMethod});
  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  Map<String, ProductDetails> _products = {};
  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String _loadingError = '';
  final Set<String> _kIds = {'minvest.elite.1month', 'minvest.elite.12months'};

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethod == PaymentMethod.inAppPurchase) {
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription.cancel();
      }, onError: (error) {
        if(mounted) setState(() => _isPurchasing = false);
      });
      _initStoreInfo();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initStoreInfo() async {
    final l10n = AppLocalizations.of(context)!;
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
          _loadingError = l10n.iapStoreNotAvailable;
        });
      }
      return;
    }
    final ProductDetailsResponse productDetailResponse =
    await _inAppPurchase.queryProductDetails(_kIds);

    if (mounted) {
      setState(() {
        _isAvailable = true;
        _products = {
          for (var p in productDetailResponse.productDetails) p.id: p
        };
        _isLoading = false;
        if (productDetailResponse.error != null) {
          _loadingError =
              l10n.iapErrorLoadingProducts(productDetailResponse.error!.message);
        } else if (_products.isEmpty) {
          _loadingError = l10n.iapNoProductsFound;
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.paymentMethod == PaymentMethod.inAppPurchase) {
      _subscription.cancel();
    }
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    final l10n = AppLocalizations.of(context)!;
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if(mounted) setState(() => _isPurchasing = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if(mounted) setState(() => _isPurchasing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.iapTransactionError(purchaseDetails.error?.message ?? 'Unknown error'))),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _verifyPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    final l10n = AppLocalizations.of(context)!;
    if(mounted) setState(() => _isPurchasing = true);

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('verifyPurchase');
      final String platform = Platform.isIOS ? 'ios' : 'android';
      Map<String, dynamic> transactionData = {};
      if (platform == 'ios') {
        transactionData['receiptData'] = purchaseDetails.verificationData.serverVerificationData;
      } else { // Android
        transactionData['purchaseToken'] = purchaseDetails.verificationData.serverVerificationData;
      }
      final HttpsCallableResult result = await callable.call<dynamic>({
        'platform': platform,
        'productId': purchaseDetails.productID,
        'transactionData': transactionData,
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.data['message'] ?? l10n.loginSuccess), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.iapVerificationError(e.message ?? '')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.iapUnknownError(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() => _isPurchasing = false);
    }
  }

  void _handlePurchase(ProductDetails productDetails) {
    final PurchaseParam purchaseParam =
    PurchaseParam(productDetails: productDetails);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.packageTitle,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D1117),
                  Color(0xFF161B22),
                  Color.fromARGB(255, 20, 29, 110)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: widget.paymentMethod == PaymentMethod.inAppPurchase
                ? _buildIapContent(l10n)
                : _buildVnPayContent(l10n),
          ),
          if (_isPurchasing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l10n.iapProcessingTransaction, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVnPayContent(AppLocalizations l10n) {
    final features = [
      l10n.featureReceiveAllSignals,
      l10n.featureAnalyzeReason,
      l10n.featureHighPrecisionAI,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          _PackageCard(
            tier: l10n.tierElite,
            duration: l10n.duration1Month,
            price: '\$78',
            features: features,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BankTransferScreen(
                    amountUSD: 78,
                    orderInfo: l10n.orderInfo1Month,
                    productId: 'elite_1_month_vnpay', // <<< SỬA ĐỔI Ở ĐÂY
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _PackageCard(
            tier: l10n.tierElite,
            duration: l10n.duration12Months,
            price: '\$460',
            features: features,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BankTransferScreen(
                    amountUSD: 460,
                    orderInfo: l10n.orderInfo12Months,
                    productId: 'elite_12_months_vnpay', // <<< SỬA ĐỔI Ở ĐÂY
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIapContent(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAvailable || _loadingError.isNotEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_loadingError,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
          ));
    }
    final product1Month = _products['minvest.elite.1month'];
    final product12Months = _products['minvest.elite.12months'];
    final features = [
      l10n.featureReceiveAllSignals,
      l10n.featureAnalyzeReason,
      l10n.featureHighPrecisionAI,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          _PackageCard(
            tier: l10n.tierElite,
            duration: l10n.duration1Month,
            price: product1Month?.price ?? '\$78',
            features: features,
            onPressed:
            product1Month != null ? () => _handlePurchase(product1Month) : null,
          ),
          const SizedBox(height: 24),
          _PackageCard(
            tier: l10n.tierElite,
            duration: l10n.duration12Months,
            price: product12Months?.price ?? '\$460',
            features: features,
            onPressed: product12Months != null
                ? () => _handlePurchase(product12Months)
                : null,
          ),
        ],
      ),
    );
  }
}

// Các widget con không thay đổi
class _PackageCard extends StatelessWidget {
  final String tier;
  final String duration;
  final String price;
  final List<String> features;
  final VoidCallback? onPressed;

  const _PackageCard({
    required this.tier,
    required this.duration,
    required this.price,
    required this.features,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF157CC9),
                Color(0xFF2A43B9),
                Color(0xFFC611CE),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC611CE).withOpacity(0.5),
                blurRadius: 25.0,
                spreadRadius: 5.0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_outlined,
                      color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Text(tier,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(duration,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(feature,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13))),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      price,
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber),
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    text: l10n.startNow,
                    onPressed: onPressed,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildActionButton(
    {required String text,
      required VoidCallback? onPressed,
      required bool isPrimary}) {
  final bool isEnabled = onPressed != null;
  return SizedBox(
    height: 45,
    width: 140,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: Colors.grey.withOpacity(0.2),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: isEnabled && isPrimary
              ? const LinearGradient(
            colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          color: isEnabled && !isPrimary ? const Color(0xFF151a2e) : null,
          borderRadius: BorderRadius.circular(12),
          border: isEnabled && !isPrimary
              ? Border.all(color: Colors.blueAccent)
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isEnabled ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    ),
  );
}