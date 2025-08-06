import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';

class SignalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- HÀM LẤY TÍN HIỆU ĐÃ ĐƯỢC TÁI CẤU TRÚC HOÀN TOÀN ---
  Stream<List<Signal>> getSignals(
      {required bool isLive, required String userTier}) {
    Query query = _firestore.collection('signals');

    // 1. Lọc theo trạng thái LIVE (running) hoặc END (closed)
    if (isLive) {
      query = query.where('status', isEqualTo: 'running');
    } else {
      query = query.where('status', isEqualTo: 'closed');
    }

    // Luôn sắp xếp theo thời gian mới nhất
    query = query.orderBy('createdAt', descending: true);

    // 2. Áp dụng logic truy vấn cho tài khoản Demo trên tab LIVE
    // Lấy 20 tín hiệu để UI có thể hiển thị 8 và làm mờ 12 cái còn lại.
    if (isLive && userTier == 'demo') {
      query = query.limit(20);
    }

    // 3. Trả về Stream<List<Signal>> đã được xử lý
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Signal.fromFirestore(doc))
          .toList();
    });
  }
}