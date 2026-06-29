import 'package:pusoy_tayo/features/game/domain/card_model.dart';

enum GamePhase { waiting, betting, dealing, arranging, comparing, finished }

class GamePlayer {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final int seat;
  final bool isReady;
  final bool hasArranged;
  final int score;

  const GamePlayer({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.seat,
    this.isReady = false,
    this.hasArranged = false,
    this.score = 0,
  });

  GamePlayer copyWith({
    bool? isReady,
    bool? hasArranged,
    int? score,
  }) {
    return GamePlayer(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      seat: seat,
      isReady: isReady ?? this.isReady,
      hasArranged: hasArranged ?? this.hasArranged,
      score: score ?? this.score,
    );
  }

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      seat: json['seat'] as int,
      isReady: json['isReady'] as bool? ?? false,
      hasArranged: json['hasArranged'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'seat': seat,
    'isReady': isReady,
    'hasArranged': hasArranged,
    'score': score,
  };
}

class GameState {
  final String roomCode;
  final GamePhase phase;
  final List<GamePlayer> players;
  final List<PlayingCard> myCards;
  final List<PlayingCard> frontHand;
  final List<PlayingCard> middleHand;
  final List<PlayingCard> backHand;
  final int timerSeconds;
  final String? winnerId;
  final Map<String, int> scores;
  final String? currentMessage;

  const GameState({
    required this.roomCode,
    this.phase = GamePhase.waiting,
    this.players = const [],
    this.myCards = const [],
    this.frontHand = const [],
    this.middleHand = const [],
    this.backHand = const [],
    this.timerSeconds = 0,
    this.winnerId,
    this.scores = const {},
    this.currentMessage,
  });

  GameState copyWith({
    GamePhase? phase,
    List<GamePlayer>? players,
    List<PlayingCard>? myCards,
    List<PlayingCard>? frontHand,
    List<PlayingCard>? middleHand,
    List<PlayingCard>? backHand,
    int? timerSeconds,
    String? winnerId,
    Map<String, int>? scores,
    String? currentMessage,
  }) {
    return GameState(
      roomCode: roomCode,
      phase: phase ?? this.phase,
      players: players ?? this.players,
      myCards: myCards ?? this.myCards,
      frontHand: frontHand ?? this.frontHand,
      middleHand: middleHand ?? this.middleHand,
      backHand: backHand ?? this.backHand,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      winnerId: winnerId ?? this.winnerId,
      scores: scores ?? this.scores,
      currentMessage: currentMessage ?? this.currentMessage,
    );
  }

  int get playerCount => players.length;
  bool get isFull => players.length == 4;
  bool get allReady => players.length >= 2 && players.every((p) => p.isReady);
  bool get allArranged => players.every((p) => p.hasArranged);

  int get unassignedCardCount =>
      myCards.length - frontHand.length - middleHand.length - backHand.length;

  List<PlayingCard> get unassignedCards {
    final assigned = {...frontHand, ...middleHand, ...backHand};
    return myCards.where((c) => !assigned.contains(c)).toList();
  }
}
