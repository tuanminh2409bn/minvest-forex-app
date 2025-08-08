// lib/features/signals/services/signal_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Thêm import này
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';

class SignalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Thêm FirebaseAuth để kiểm tra trạng thái đăng nhập
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Signal>> getSignals(
      {required bool isLive, required String userTier}) {

    // ▼▼▼ BỨC TƯỜNG LỬA NẰM Ở ĐÂY ▼▼▼
    // Nếu không có người dùng đăng nhập, trả về một stream rỗng ngay lập tức.
    // Sẽ không có bất kỳ truy vấn nào được gửi đến Firestore.
    if (_auth.currentUser == null) {
      return Stream.value([]); // Trả về một danh sách rỗng an toàn
    }
    // ▲▲▲ KẾT THÚC BỨC TƯỜNG LỬA ▲▲▲

    // Nếu có người dùng đăng nhập, tiếp tục truy vấn như bình thường.
    Query query = _firestore.collection('signals');

    if (isLive) {
      query = query.where('status', isEqualTo: 'running');
    } else {
      query = query.where('status', isEqualTo: 'closed');
    }

    query = query.orderBy('createdAt', descending: true);

    if (isLive && userTier == 'demo') {
      query = query.limit(20);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Signal.fromFirestore(doc))
          .toList();
    });
  }

  Future<Signal?> getSignalById(String signalId) async {
    try {
      final docSnapshot =
      await _firestore.collection('signals').doc(signalId).get();
      if (docSnapshot.exists) {
        return Signal.fromFirestore(docSnapshot);
      }
    } catch (e) {
      print('Lỗi khi lấy tín hiệu theo ID: $e');
    }
    return null;
  }
}