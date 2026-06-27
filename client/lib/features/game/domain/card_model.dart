import 'package:equatable/equatable.dart';
import 'package:pusoy_tayo/core/constants/game_constants.dart';

class PlayingCard extends Equatable implements Comparable<PlayingCard> {
  final int rank;
  final String suit;

  const PlayingCard({required this.rank, required this.suit});

  int get suitValue => GameConstants.suitOrder.indexOf(suit);

  int get pusoyRank {
    if (rank == 2) return 15;
    if (rank == 1 || rank == 14) return 14;
    return rank;
  }

  String get rankDisplay => GameConstants.rankNames[pusoyRank] ?? '$rank';
  String get suitSymbol => GameConstants.suitSymbols[suit] ?? suit;
  String get display => '$rankDisplay$suitSymbol';

  bool get isRed => suit == 'H' || suit == 'D';

  @override
  int compareTo(PlayingCard other) {
    final rankCmp = pusoyRank.compareTo(other.pusoyRank);
    if (rankCmp != 0) return rankCmp;
    return suitValue.compareTo(other.suitValue);
  }

  @override
  List<Object?> get props => [rank, suit];

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(rank: json['rank'] as int, suit: json['suit'] as String);
  }

  Map<String, dynamic> toJson() => {'rank': rank, 'suit': suit};

  static List<PlayingCard> fullDeck() {
    final deck = <PlayingCard>[];
    for (final suit in GameConstants.suitOrder) {
      for (int rank = 3; rank <= 15; rank++) {
        deck.add(PlayingCard(rank: rank, suit: suit));
      }
    }
    return deck;
  }

  @override
  String toString() => display;
}
