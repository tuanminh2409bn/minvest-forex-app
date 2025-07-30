import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Set chứa ID các sản phẩm bạn đã tạo trên Store
  final Set<String> _kIds = {'elite_1_month', 'elite_12_months'};

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isStoreAvailable = false;
  bool get isStoreAvailable => _isStoreAvailable;

  // Hàm khởi tạo
  void initialize() async {
    _isStoreAvailable = await _inAppPurchase.isAvailable();
    if (_isStoreAvailable) {
      await _loadProducts();
      _subscription = _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        // Xử lý lỗi
      });
    }
    notifyListeners();
  }

  // Hàm tải thông tin sản phẩm từ Store
  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      print('Sản phẩm không tìm thấy: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    notifyListeners();
  }

  // Hàm thực hiện mua sản phẩm
  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Lắng nghe và xử lý các cập nhật từ giao dịch
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Giao dịch đang chờ xử lý
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Giao dịch lỗi
          print('Lỗi giao dịch: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _handleSuccessfulPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  // Xử lý khi giao dịch thành công
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: BƯỚC QUAN TRỌNG
    // 1. Lấy "biên lai" (receipt) từ `purchaseDetails`.
    // 2. Gửi biên lai này lên một Firebase Function mới (ví dụ: `verifyPurchase`).
    // 3. Backend sẽ xác thực biên lai với Google/Apple.
    // 4. Nếu hợp lệ, backend sẽ nâng cấp tài khoản cho user trên Firestore.
    // 5. App sẽ tự động cập nhật qua UserProvider.

    print('Giao dịch thành công cho sản phẩm: ${purchaseDetails.productID}');
    // Sau khi backend xác nhận, điều hướng tới màn hình thành công
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}