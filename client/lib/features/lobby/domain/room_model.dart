class RoomModel {
  final String code;
  final String status;
  final String gameMode;
  final int betAmount;
  final String currency;
  final int maxPlayers;
  final int currentPlayers;
  final String createdBy;
  final bool isPrivate;
  final DateTime createdAt;

  const RoomModel({
    required this.code,
    required this.status,
    required this.gameMode,
    required this.betAmount,
    required this.currency,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.createdBy,
    this.isPrivate = false,
    required this.createdAt,
  });

  bool get isFull => currentPlayers >= maxPlayers;
  bool get isWaiting => status == 'waiting';

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      code: json['code'] as String,
      status: json['status'] as String,
      gameMode: json['gameMode'] as String,
      betAmount: json['betAmount'] as int,
      currency: json['currency'] as String,
      maxPlayers: json['maxPlayers'] as int,
      currentPlayers: json['currentPlayers'] as int,
      createdBy: json['createdBy'] as String,
      isPrivate: json['isPrivate'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'status': status,
    'gameMode': gameMode,
    'betAmount': betAmount,
    'currency': currency,
    'maxPlayers': maxPlayers,
    'currentPlayers': currentPlayers,
    'createdBy': createdBy,
    'isPrivate': isPrivate,
    'createdAt': createdAt.toIso8601String(),
  };
}
