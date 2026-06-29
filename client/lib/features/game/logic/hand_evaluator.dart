import 'package:pusoy_tayo/core/constants/game_constants.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';

class HandEvaluator {
  HandEvaluator._();

  static HandResult evaluate(List<PlayingCard> cards) {
    if (cards.isEmpty) {
      return const HandResult(type: HandType.highCard, rankValues: []);
    }

    final sorted = List<PlayingCard>.from(cards)..sort();

    if (cards.length == 1) return _evaluateSingle(sorted);
    if (cards.length == 2) return _evaluatePair(sorted);
    if (cards.length == 3) return _evaluateThree(sorted);
    if (cards.length == 5) return _evaluateFive(sorted);

    return HandResult(
      type: HandType.highCard,
      rankValues: sorted.map((c) => c.pusoyRank).toList()..sort((a, b) => b.compareTo(a)),
      highSuitValue: sorted.last.suitValue,
    );
  }

  static HandResult _evaluateSingle(List<PlayingCard> cards) {
    final card = cards[0];
    return HandResult(
      type: HandType.highCard,
      rankValues: [card.pusoyRank],
      highSuitValue: card.suitValue,
    );
  }

  static HandResult _evaluatePair(List<PlayingCard> cards) {
    if (cards[0].pusoyRank == cards[1].pusoyRank) {
      return HandResult(
        type: HandType.pair,
        rankValues: [cards[0].pusoyRank],
        highSuitValue: cards.map((c) => c.suitValue).reduce((a, b) => a > b ? a : b),
      );
    }
    return HandResult(
      type: HandType.highCard,
      rankValues: cards.map((c) => c.pusoyRank).toList()..sort((a, b) => b.compareTo(a)),
      highSuitValue: cards.last.suitValue,
    );
  }

  static HandResult _evaluateThree(List<PlayingCard> cards) {
    final ranks = cards.map((c) => c.pusoyRank).toList()
      ..sort((a, b) => b.compareTo(a));
    final counts = _rankCounts(cards);
    final maxSuit = cards.map((c) => c.suitValue).reduce((a, b) => a > b ? a : b);

    if (counts.values.any((v) => v == 3)) {
      return HandResult(
        type: HandType.threeOfAKind,
        rankValues: [ranks[0]],
        highSuitValue: maxSuit,
      );
    }

    final pairRanks = counts.entries.where((e) => e.value == 2).map((e) => e.key);
    if (pairRanks.isNotEmpty) {
      final pr = pairRanks.first;
      final kicker = ranks.firstWhere((r) => r != pr);
      return HandResult(
        type: HandType.pair,
        rankValues: [pr, kicker],
        highSuitValue: cards
            .where((c) => c.pusoyRank == pr)
            .map((c) => c.suitValue)
            .reduce((a, b) => a > b ? a : b),
      );
    }

    return HandResult(
      type: HandType.highCard,
      rankValues: ranks,
      highSuitValue: maxSuit,
    );
  }

  static HandResult _evaluateFive(List<PlayingCard> sorted) {
    final isFlush = _isFlush(sorted);
    final isStraight = _isStraight(sorted);

    if (isFlush && isStraight) {
      final ranks = sorted.map((c) => c.pusoyRank).toList();
      if (ranks.contains(14) && ranks.contains(13) && ranks.contains(12) &&
          ranks.contains(11) && ranks.contains(10)) {
        return HandResult(
          type: HandType.royalFlush,
          rankValues: [sorted.last.pusoyRank],
          highSuitValue: sorted.last.suitValue,
        );
      }
      return HandResult(
        type: HandType.straightFlush,
        rankValues: [_straightHighCard(sorted)],
        highSuitValue: sorted.last.suitValue,
      );
    }

    final fourKind = _findFourOfAKind(sorted);
    if (fourKind != null) return fourKind;

    final fullHouse = _findFullHouse(sorted);
    if (fullHouse != null) return fullHouse;

    if (isFlush) {
      return HandResult(
        type: HandType.flush,
        rankValues: sorted.map((c) => c.pusoyRank).toList()..sort((a, b) => b.compareTo(a)),
        highSuitValue: sorted[0].suitValue,
      );
    }

    if (isStraight) {
      return HandResult(
        type: HandType.straight,
        rankValues: [_straightHighCard(sorted)],
        highSuitValue: sorted.last.suitValue,
      );
    }

    final trips = _findThreeOfAKind(sorted);
    if (trips != null) return trips;

    final twoPair = _findTwoPair(sorted);
    if (twoPair != null) return twoPair;

    final pair = _findPair(sorted);
    if (pair != null) return pair;

    return HandResult(
      type: HandType.highCard,
      rankValues: sorted.map((c) => c.pusoyRank).toList()..sort((a, b) => b.compareTo(a)),
      highSuitValue: sorted.last.suitValue,
    );
  }

  static Map<int, int> _rankCounts(List<PlayingCard> cards) {
    final m = <int, int>{};
    for (final c in cards) {
      m[c.pusoyRank] = (m[c.pusoyRank] ?? 0) + 1;
    }
    return m;
  }

  static int _maxSuitOfRank(List<PlayingCard> cards, int rank) => cards
      .where((c) => c.pusoyRank == rank)
      .map((c) => c.suitValue)
      .reduce((a, b) => a > b ? a : b);

  static HandResult? _findThreeOfAKind(List<PlayingCard> sorted) {
    final counts = _rankCounts(sorted);
    final trip = counts.entries.where((e) => e.value == 3).map((e) => e.key);
    if (trip.isEmpty) return null;
    final tripRank = trip.first;
    final kickers = sorted
        .map((c) => c.pusoyRank)
        .where((r) => r != tripRank)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return HandResult(
      type: HandType.threeOfAKind,
      rankValues: [tripRank, ...kickers],
      highSuitValue: _maxSuitOfRank(sorted, tripRank),
    );
  }

  static HandResult? _findTwoPair(List<PlayingCard> sorted) {
    final counts = _rankCounts(sorted);
    final pairs = counts.entries.where((e) => e.value == 2).map((e) => e.key).toList()
      ..sort((a, b) => b.compareTo(a));
    if (pairs.length < 2) return null;
    final high = pairs[0];
    final low = pairs[1];
    final kicker =
        sorted.map((c) => c.pusoyRank).firstWhere((r) => r != high && r != low);
    return HandResult(
      type: HandType.twoPair,
      rankValues: [high, low, kicker],
      highSuitValue: _maxSuitOfRank(sorted, high),
    );
  }

  static HandResult? _findPair(List<PlayingCard> sorted) {
    final counts = _rankCounts(sorted);
    final pairRanks = counts.entries.where((e) => e.value == 2).map((e) => e.key);
    if (pairRanks.isEmpty) return null;
    final pr = pairRanks.first;
    final kickers = sorted
        .map((c) => c.pusoyRank)
        .where((r) => r != pr)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return HandResult(
      type: HandType.pair,
      rankValues: [pr, ...kickers],
      highSuitValue: _maxSuitOfRank(sorted, pr),
    );
  }

  static bool _isFlush(List<PlayingCard> cards) {
    return cards.every((c) => c.suit == cards[0].suit);
  }

  /// Straights use the natural poker order where the "2" is LOW (2-3-4-5-6 is
  /// a straight), even though 2 is the highest card for pair/high-card
  /// comparisons. The deck stores "2" as pusoyRank 15, so map it back to 2 here.
  static List<int> _straightValues(List<PlayingCard> cards) {
    return cards.map((c) => c.pusoyRank == 15 ? 2 : c.pusoyRank).toList()
      ..sort();
  }

  static bool _consecutive(List<int> sorted) {
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] != 1) return false;
    }
    return true;
  }

  static bool _isStraight(List<PlayingCard> cards) {
    final v = _straightValues(cards);
    if (_consecutive(v)) return true;
    // Ace-low wheel: A-2-3-4-5 (Ace acts as 1).
    if (v.contains(14)) {
      final w = v.map((x) => x == 14 ? 1 : x).toList()..sort();
      if (_consecutive(w)) return true;
    }
    return false;
  }

  static int _straightHighCard(List<PlayingCard> cards) {
    final v = _straightValues(cards);
    if (_consecutive(v)) return v.last;
    if (v.contains(14)) {
      final w = v.map((x) => x == 14 ? 1 : x).toList()..sort();
      if (_consecutive(w)) return w.last; // 5 for the wheel
    }
    return v.last;
  }

  static HandResult? _findFourOfAKind(List<PlayingCard> sorted) {
    final rankCounts = <int, int>{};
    for (final card in sorted) {
      rankCounts[card.pusoyRank] = (rankCounts[card.pusoyRank] ?? 0) + 1;
    }

    for (final entry in rankCounts.entries) {
      if (entry.value == 4) {
        final kicker = rankCounts.keys.firstWhere((r) => r != entry.key);
        return HandResult(
          type: HandType.fourOfAKind,
          rankValues: [entry.key, kicker],
          highSuitValue: sorted
              .where((c) => c.pusoyRank == entry.key)
              .map((c) => c.suitValue)
              .reduce((a, b) => a > b ? a : b),
        );
      }
    }
    return null;
  }

  static HandResult? _findFullHouse(List<PlayingCard> sorted) {
    final rankCounts = <int, int>{};
    for (final card in sorted) {
      rankCounts[card.pusoyRank] = (rankCounts[card.pusoyRank] ?? 0) + 1;
    }

    int? threeRank;
    int? twoRank;

    for (final entry in rankCounts.entries) {
      if (entry.value == 3) threeRank = entry.key;
      if (entry.value == 2) twoRank = entry.key;
    }

    if (threeRank != null && twoRank != null) {
      return HandResult(
        type: HandType.fullHouse,
        rankValues: [threeRank, twoRank],
        highSuitValue: sorted
            .where((c) => c.pusoyRank == threeRank)
            .map((c) => c.suitValue)
            .reduce((a, b) => a > b ? a : b),
      );
    }
    return null;
  }

  static bool isValidFrontHand(List<PlayingCard> cards) {
    return cards.length == GameConstants.frontHandSize;
  }

  static bool isValidMiddleHand(List<PlayingCard> cards) {
    return cards.length == GameConstants.middleHandSize;
  }

  static bool isValidBackHand(List<PlayingCard> cards) {
    return cards.length == GameConstants.backHandSize;
  }

  static bool isValidArrangement(
    List<PlayingCard> front,
    List<PlayingCard> middle,
    List<PlayingCard> back,
  ) {
    if (!isValidFrontHand(front) || !isValidMiddleHand(middle) || !isValidBackHand(back)) {
      return false;
    }

    final frontResult = evaluate(front);
    final middleResult = evaluate(middle);
    final backResult = evaluate(back);

    return middleResult.compareTo(frontResult) >= 0 &&
        backResult.compareTo(middleResult) >= 0;
  }
}
