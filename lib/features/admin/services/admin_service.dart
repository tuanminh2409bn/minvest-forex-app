// lib/features/admin/services/admin_service.dart

import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: "asia-southeast1");

  Future<String> manageUserStatus({
    required List<String> userIds,
    required String newStatus,
    String? reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('manageUserStatus');
      final result = await callable.call(<String, dynamic>{
        'userIds': userIds,
        'newStatus': newStatus,
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