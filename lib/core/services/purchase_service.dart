//lib/core/services/purchase_service.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Set<String> _androidIds = {'elite_1_month', 'elite_12_months'};
  final Set<String> _iosIds = {'minvest.elite.1month', 'minvest.elite.12months'};

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isStoreAvailable = false;
  bool get isStoreAvailable => _isStoreAvailable;

  bool _isPurchasePending = false;
  bool get isPurchasePending => _isPurchasePending;

  void initialize() async {
    _isStoreAvailable = await _inAppPurchase.isAvailable();
    if (_isStoreAvailable) {
      await _loadProducts();
      _subscription = _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        debugPrint("Lỗi stream mua hàng: $error");
        _setPurchasePending(false);
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final Set<String> kIds = Platform.isIOS ? _iosIds : _androidIds;
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Sản phẩm không tìm thấy: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _setPurchasePending(true);
          break;
        case PurchaseStatus.error:
          debugPrint('Lỗi giao dịch: ${purchaseDetails.error}');
          _setPurchasePending(false);
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        default:
          break;
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('Giao dịch thành công cho sản phẩm: ${purchaseDetails.productID}. Đang xác thực với server...');

    try {
      final String platform = Platform.isIOS ? 'ios' : 'android';
      final String verificationData = purchaseDetails.verificationData.serverVerificationData;

      final payload = {
        'platform': platform,
        'productId': purchaseDetails.productID,
        'transactionData': {
          platform == 'ios' ? 'receiptData' : 'purchaseToken': verificationData,
        },
      };

      debugPrint("Đang gửi payload xác thực: $payload");
      final HttpsCallable callable = _functions.httpsCallable('verifyPurchase');
      final HttpsCallableResult result = await callable.call(payload);

      if (result.data['success'] == true) {
        debugPrint("Xác thực thành công! Server đã nâng cấp tài khoản.");
      } else {
        debugPrint("Server từ chối xác thực: ${result.data['message']}");
      }
    } catch (e) {
      debugPrint("Lỗi nghiêm trọng khi gọi hàm verifyPurchase: $e");
      if (e is FirebaseFunctionsException) {
        debugPrint("Chi tiết lỗi Firebase: ${e.code} - ${e.message}");
      }
    } finally {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
      _setPurchasePending(false);
    }
  }

  void _setPurchasePending(bool isPending) {
    _isPurchasePending = isPending;
    notifyListeners();
  }
}