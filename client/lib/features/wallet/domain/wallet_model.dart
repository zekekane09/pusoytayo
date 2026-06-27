class WalletModel {
  final String id;
  final String userId;
  final int coins;
  final int cash;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.coins,
    required this.cash,
    required this.updatedAt,
  });

  String get formattedCoins => coins.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String get formattedCash =>
      '₱${(cash / 100).toStringAsFixed(2)}';

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      coins: json['coins'] as int,
      cash: json['cash'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
