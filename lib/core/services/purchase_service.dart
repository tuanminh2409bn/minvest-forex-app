// lib/core/services/purchase_service.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';


class PurchaseService extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Set<String> _androidIds = {'elite_1_month', 'elite_12_months'};
  final Set<String> _iosIds = {'minvest.1month', 'minvest.12month'};

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isStoreAvailable = false;
  bool get isStoreAvailable => _isStoreAvailable;

  bool _isPurchasePending = false;
  bool get isPurchasePending => _isPurchasePending;

  Future<void> initialize() async {
    _isStoreAvailable = await _inAppPurchase.isAvailable();
    debugPrint("Store khả dụng: $_isStoreAvailable");
    if (_isStoreAvailable) {
      await _loadProducts();

      if (Platform.isIOS) {
        await _clearStuckTransactions();
      }

      _subscription = _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
        debugPrint("🔴 Lắng nghe được ${purchaseDetailsList.length} sự kiện từ purchaseStream!");
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        debugPrint("🔴 purchaseStream đã đóng (onDone).");
        _subscription?.cancel();
      }, onError: (error) {
        debugPrint("🔴 Lỗi stream mua hàng: $error");
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
    debugPrint("Đã tải ${_products.length} sản phẩm.");
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      debugPrint("   ➡️ Đang xử lý giao dịch: ${purchaseDetails.productID} - Trạng thái: ${purchaseDetails.status}");

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint("      ⏳ Trạng thái: Pending. Hiển thị loading...");
          _setPurchasePending(true);
          break;
        case PurchaseStatus.error:
          debugPrint("      ❌ Trạng thái: Error. Lỗi: ${purchaseDetails.error}");
          _setPurchasePending(false);
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
            debugPrint("      ✅ Đã gọi completePurchase cho giao dịch lỗi để xóa khỏi queue.");
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint("      🎉 Trạng thái: ${purchaseDetails.status}. Chuẩn bị gọi hàm xác thực!");
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          debugPrint("      🚫 Trạng thái: Canceled. Người dùng đã hủy giao dịch.");
          _setPurchasePending(false);
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
            debugPrint("      ✅ Đã gọi completePurchase cho giao dịch bị hủy để xóa khỏi queue.");
          }
          break;
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('✅ Giao dịch thành công cục bộ cho sản phẩm: ${purchaseDetails.productID}.');

    debugPrint('⏳ Bắt đầu chờ 5 giây để đảm bảo biên lai được đồng bộ...');
    await Future.delayed(const Duration(seconds: 5));
    debugPrint('...Đã chờ xong. Tiếp tục xử lý.');

    final String verificationData = purchaseDetails.verificationData.serverVerificationData;
    debugPrint('🧾 Dữ liệu biên lai gốc (độ dài): ${verificationData.length} ký tự.');

    if (verificationData.isEmpty) {
      debugPrint('❌ CẢNH BÁO: Dữ liệu biên lai (verificationData) bị rỗng!');
      _setPurchasePending(false);
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
      return;
    }
    debugPrint('🧾 300 ký tự đầu của biên lai: ${verificationData.substring(0, verificationData.length > 300 ? 300 : verificationData.length)}...');

    _setPurchasePending(true);

    try {
      final String platform = Platform.isIOS ? 'ios' : 'android';
      final payload = {
        'platform': platform,
        'productId': purchaseDetails.productID,
        'transactionData': {'receiptData': verificationData},
      };

      debugPrint("🚀 Đang gửi payload lên Cloud Function 'verifyPurchase'...");
      final HttpsCallable callable = _functions.httpsCallable('verifyPurchase');
      final HttpsCallableResult result = await callable.call(payload);

      if (result.data['success'] == true) {
        debugPrint("🎉 XÁC THỰC THÀNH CÔNG! Server đã nâng cấp tài khoản.");
      } else {
        debugPrint("❌ SERVER TỪ CHỐI XÁC THỰC: ${result.data['message']}");
      }
    } catch (e) {
      debugPrint("🔥 LỖI NGHIÊM TRỌNG KHI GỌI HÀM VERIFYPURCHASE 🔥");
      if (e is FirebaseFunctionsException) {
        debugPrint("   - MÃ LỖI FIREBASE: ${e.code}");
        debugPrint("   - THÔNG ĐIỆP: ${e.message}");
        debugPrint("   - CHI TIẾT: ${e.details}");
      } else {
        debugPrint("   - LỖI KHÔNG XÁC ĐỊNH: $e");
      }
    } finally {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        debugPrint("✅ Đã gọi completePurchase() cho giao dịch.");
      }
      _setPurchasePending(false);
    }
  }

  void _setPurchasePending(bool isPending) {
    _isPurchasePending = isPending;
    notifyListeners();
  }

  Future<void> _clearStuckTransactions() async {
    try {
      debugPrint("🧹 Đang kiểm tra các giao dịch bị kẹt trên App Store...");
      final transactions = await SKPaymentQueueWrapper().transactions();
      if (transactions.isEmpty) {
        debugPrint("🧹 Không có giao dịch nào bị kẹt. Hàng đợi sạch sẽ.");
        return;
      }
      debugPrint("🧹 Tìm thấy ${transactions.length} giao dịch trong hàng đợi. Đang xử lý...");
      for (final skPaymentTransaction in transactions) {
        SKPaymentQueueWrapper().finishTransaction(skPaymentTransaction);
        debugPrint("   🧹 Đã cố gắng finish transaction: ${skPaymentTransaction.transactionIdentifier}");
      }
    } catch (e) {
      debugPrint("🔥 Lỗi khi dọn dẹp giao dịch bị kẹt: $e");
    }
  }
}