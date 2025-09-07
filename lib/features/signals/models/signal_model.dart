import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

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

  String getTranslatedResult(AppLocalizations l10n) {
    // Ưu tiên xử lý trạng thái `result` trước
    switch (result) {
      case 'TP1 Hit':
        return l10n.tp1Hit;
      case 'TP2 Hit':
        return l10n.tp2Hit;
      case 'TP3 Hit':
        return l10n.tp3Hit;
      case 'SL Hit':
        return l10n.slHit;
      case 'Cancelled':
      case 'Cancelled (new signal)':
        return l10n.cancelled;
      case 'Exited by Admin':
        return l10n.exitedByAdmin;
    }

    // Nếu result không khớp các case trên, xét đến trạng thái chung
    if (status == 'running') {
      return isMatched ? l10n.matched : l10n.notMatched;
    }

    // Trường hợp dự phòng cuối cùng
    return result ?? l10n.signalClosed;
  }

  Color getStatusColor() {
    // Ưu tiên xử lý màu theo `result` trước
    switch (result) {
      case 'TP1 Hit':
      case 'TP2 Hit':
      case 'TP3 Hit':
        return Colors.greenAccent.shade400;
      case 'SL Hit':
        return Colors.redAccent;
      case 'Cancelled':
      case 'Cancelled (new signal)':
      case 'Exited by Admin':
        return Colors.grey;
    }

    // Nếu result không khớp, xét màu theo trạng thái chung
    if (status == 'running') {
      if (result != null && result!.contains("Hit")) return Colors.tealAccent.shade400;
      return isMatched ? Colors.greenAccent.shade400 : Colors.amber.shade400;
    }

    // Màu dự phòng
    return Colors.blueGrey.shade200;
  }
}