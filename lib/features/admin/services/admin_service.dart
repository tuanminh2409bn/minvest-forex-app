// lib/features/admin/services/admin_service.dart

import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: "asia-southeast1");

  // Đổi tên hàm và tham số cho đúng nghiệp vụ
  Future<String> downgradeUsersToFree({
    required List<String> userIds,
    required String reason, // Lý do bây giờ là bắt buộc
  }) async {
    try {
      // Gọi đúng tên Cloud Function mới
      final callable = _functions.httpsCallable('downgradeUsersToFree');
      final result = await callable.call(<String, dynamic>{
        'userIds': userIds,
        // Tham số `newStatus` không còn nữa, chỉ cần `reason`
        'reason': reason,
      });
      return result.data['message'] ?? 'Thao tác thành công!';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Có lỗi xảy ra.';
    } catch (e) {
      return 'Đã có lỗi không xác định xảy ra.';
    }
  }
}