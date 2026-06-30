class WalletModel {
  final String id;
  final String userId;
  final int coins;
  final int cash;
  final int bonusLocked;
  final int withdrawable;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.coins,
    required this.cash,
    this.bonusLocked = 0,
    this.withdrawable = 0,
    required this.updatedAt,
  });

  String get formattedCoins => coins.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String get formattedCash =>
      '₱${(cash / 100).toStringAsFixed(2)}';

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    // coins/cash are bigint on the server and arrive as strings.
    int toInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return WalletModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      coins: toInt(json['coins']),
      cash: toInt(json['cash']),
      bonusLocked: toInt(json['bonusLocked']),
      withdrawable: toInt(json['withdrawable']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class TransactionModel {
  final String id;
  final String walletId;
  final String type;
  final String currency;
  final int amount;
  final int balanceAfter;
  final String? description;
  final String status;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.status,
    required this.createdAt,
  });

  bool get isCredit =>
      type == 'deposit' || type == 'win' || type == 'bonus' || type == 'refund';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String,
      amount: json['amount'] as int,
      balanceAfter: json['balanceAfter'] as int,
      description: json['description'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
