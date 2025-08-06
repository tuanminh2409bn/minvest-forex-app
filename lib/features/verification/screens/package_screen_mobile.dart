// lib/features/verification/screens/package_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ▼▼▼ THÊM IMPORT NÀY ▼▼▼
import 'package:cloud_functions/cloud_functions.dart';
import 'package:minvest_forex_app/features/verification/models/payment_method.dart';
import 'package:minvest_forex_app/features/verification/screens/bank_transfer_screen.dart';

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
  bool _isPurchasing = false; // Biến mới để quản lý trạng thái đang xử lý giao dịch
  String _loadingError = '';
  final Set<String> _kIds = {'elite_1_month', 'elite_12_months'};

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
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
          _loadingError = 'Cửa hàng không khả dụng trên thiết bị này.';
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
          'Lỗi tải sản phẩm: ${productDetailResponse.error!.message}';
        } else if (_products.isEmpty) {
          _loadingError =
          'Không tìm thấy sản phẩm nào. Vui lòng kiểm tra lại cấu hình trên cửa hàng.';
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
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if(mounted) setState(() => _isPurchasing = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if(mounted) setState(() => _isPurchasing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi giao dịch: ${purchaseDetails.error?.message ?? 'Unknown error'}')),
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

  // ▼▼▼ HÀM ĐÃ ĐƯỢC NÂNG CẤP ĐỂ GỌI BACKEND ▼▼▼
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('verifyPurchase');

      final HttpsCallableResult result = await callable.call<dynamic>({
        'productId': purchaseDetails.productID,
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
      });

      if(mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.data['message'] ?? 'Giao dịch thành công!'), backgroundColor: Colors.green),
        );
        // Có thể điều hướng người dùng về màn hình chính hoặc hồ sơ
        Navigator.of(context).pop();
      }

    } on FirebaseFunctionsException catch (e) {
      if(mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xác thực: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi không xác định: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handlePurchase(ProductDetails productDetails) {
    final PurchaseParam purchaseParam =
    PurchaseParam(productDetails: productDetails);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('PACKAGE',
            style: TextStyle(
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
                ? _buildIapContent()
                : _buildVnPayContent(),
          ),
          // Thêm lớp phủ loading khi đang xử lý giao dịch
          if (_isPurchasing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang xử lý giao dịch...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVnPayContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          _PackageCard(
            tier: 'ELITE',
            duration: '1 month',
            price: '\$78',
            features: const [
              'Receive all signals of the day',
              'Analyze the reason for entering the order',
              'High-precision AI signal',
            ],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BankTransferScreen(
                    amountUSD: 78,
                    orderInfo: 'Thanh toan goi Elite 1 thang',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _PackageCard(
            tier: 'ELITE',
            duration: '12 month',
            price: '\$460',
            features: const [
              'Receive all signals of the day',
              'Analyze the reason for entering the order',
              'High-precision AI signal',
            ],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BankTransferScreen(
                    amountUSD: 460,
                    orderInfo: 'Thanh toan goi Elite 12 thang',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIapContent() {
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
    final product1Month = _products['elite_1_month'];
    final product12Months = _products['elite_12_months'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          _PackageCard(
            tier: 'ELITE',
            duration: '1 month',
            price: '\$78',
            features: const [
              'Receive all signals of the day',
              'Analyze the reason for entering the order',
              'High-precision AI signal',
            ],
            onPressed:
            product1Month != null ? () => _handlePurchase(product1Month) : null,
          ),
          const SizedBox(height: 24),
          _PackageCard(
            tier: 'ELITE',
            duration: '12 month',
            price: '\$460',
            features: const [
              'Receive all signals of the day',
              'Analyze the reason for entering the order',
              'High-precision AI signal',
            ],
            onPressed: product12Months != null
                ? () => _handlePurchase(product12Months)
                : null,
          ),
        ],
      ),
    );
  }
}

// ... (_PackageCard và _buildActionButton giữ nguyên)
class _PackageCard extends StatelessWidget {
  //... (Nội dung không đổi)
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
                    text: 'START NOW',
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
          child: Text(
            text,
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