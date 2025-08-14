import 'package:cloud_firestore/cloud_firestore.dart';

class Signal {
  final String id;
  final String symbol;
  final String type;
  final String status;
  final double entryPrice;
  final double stopLoss;
  final List<dynamic> takeProfits;
  final Timestamp createdAt;
  final String? result;
  final num? pips;
  final dynamic reason;
  final String matchStatus;
  final List<int> hitTps;
  final bool isMatched;

  Signal({
    required this.id,
    required this.symbol,
    required this.type,
    required this.status,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfits,
    required this.createdAt,
    this.result,
    this.pips,
    this.reason,
    required this.matchStatus,
    this.hitTps = const [],
    this.isMatched = false,
  });

  factory Signal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Signal(
      id: doc.id,
      symbol: data['symbol'] ?? '',
      type: data['type'] ?? 'buy',
      status: data['status'] ?? 'running',
      entryPrice: (data['entryPrice'] ?? 0.0).toDouble(),
      stopLoss: (data['stopLoss'] ?? 0.0).toDouble(),
      takeProfits: List.from(data['takeProfits'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      result: data['result'],
      pips: data['pips'],
      reason: data['reason'],
      matchStatus: data['matchStatus'] ?? 'NOT MATCHED',
      hitTps: List<int>.from(data['hitTps'] ?? []),
      isMatched: data['isMatched'] ?? false,
    );
  }
}