import 'package:cloud_firestore/cloud_firestore.dart';

class SignalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- SỬA LỖI Ở ĐÂY: Thêm tham số {String? userTier} ---
  Stream<QuerySnapshot> getRunningSignals({String? userTier}) {
    Query query = _firestore
        .collection('signals')
        .where('status', isEqualTo: 'running')
        .orderBy('createdAt', descending: true);

    // Nếu là tài khoản Demo, chỉ lấy 8 tín hiệu
    if (userTier == 'demo') {
      query = query.limit(8);
    }

    return query.snapshots();
  }

  // --- SỬA LỖI Ở ĐÂY: Thêm tham số {String? userTier} ---
  Stream<QuerySnapshot> getClosedSignals({String? userTier}) {
    Query query = _firestore
        .collection('signals')
        .where('status', isEqualTo: 'closed')
        .orderBy('createdAt', descending: true);
    return query.snapshots();
  }
}