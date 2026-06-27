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
    final ranks = cards.map((c) => c.pusoyRank).toList();
    if (ranks.toSet().length == 1) {
      return HandResult(
        type: HandType.threeOfAKind,
        rankValues: [ranks[0]],
        highSuitValue: cards.map((c) => c.suitValue).reduce((a, b) => a > b ? a : b),
      );
    }
    return HandResult(
      type: HandType.highCard,
      rankValues: ranks..sort((a, b) => b.compareTo(a)),
      highSuitValue: cards.map((c) => c.suitValue).reduce((a, b) => a > b ? a : b),
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

    return HandResult(
      type: HandType.highCard,
      rankValues: sorted.map((c) => c.pusoyRank).toList()..sort((a, b) => b.compareTo(a)),
      highSuitValue: sorted.last.suitValue,
    );
  }

  static bool _isFlush(List<PlayingCard> cards) {
    return cards.every((c) => c.suit == cards[0].suit);
  }

  static bool _isStraight(List<PlayingCard> cards) {
    final ranks = cards.map((c) => c.pusoyRank).toList()..sort();

    for (int i = 1; i < ranks.length; i++) {
      if (ranks[i] - ranks[i - 1] != 1) {
        // Check A-2-3-4-5 wrap (in Pusoy: 14-15-3-4-5 is NOT valid)
        // Check 10-J-Q-K-A (10-11-12-13-14 is valid)
        return false;
      }
    }
    return true;
  }

  static int _straightHighCard(List<PlayingCard> cards) {
    final ranks = cards.map((c) => c.pusoyRank).toList()..sort();
    return ranks.last;
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
