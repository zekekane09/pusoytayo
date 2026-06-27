import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';

class ComparisonResult {
  final int playerIndex;
  final int opponentIndex;
  final int rowIndex;
  final int winner;
  final HandResult playerHand;
  final HandResult opponentHand;

  const ComparisonResult({
    required this.playerIndex,
    required this.opponentIndex,
    required this.rowIndex,
    required this.winner,
    required this.playerHand,
    required this.opponentHand,
  });
}

class PlayerArrangement {
  final int playerIndex;
  final List<PlayingCard> front;
  final List<PlayingCard> middle;
  final List<PlayingCard> back;

  const PlayerArrangement({
    required this.playerIndex,
    required this.front,
    required this.middle,
    required this.back,
  });

  HandResult get frontResult => HandEvaluator.evaluate(front);
  HandResult get middleResult => HandEvaluator.evaluate(middle);
  HandResult get backResult => HandEvaluator.evaluate(back);
}

class ScoringResult {
  final Map<int, int> scores;
  final List<ComparisonResult> comparisons;
  final int? scoopWinner;

  const ScoringResult({
    required this.scores,
    required this.comparisons,
    this.scoopWinner,
  });
}

class HandComparator {
  HandComparator._();

  static int compareHands(List<PlayingCard> hand1, List<PlayingCard> hand2) {
    final result1 = HandEvaluator.evaluate(hand1);
    final result2 = HandEvaluator.evaluate(hand2);
    return result1.compareTo(result2);
  }

  static ScoringResult calculateScores(List<PlayerArrangement> arrangements) {
    final scores = <int, int>{};
    final comparisons = <ComparisonResult>[];

    for (final arr in arrangements) {
      scores[arr.playerIndex] = 0;
    }

    for (int i = 0; i < arrangements.length; i++) {
      for (int j = i + 1; j < arrangements.length; j++) {
        final a = arrangements[i];
        final b = arrangements[j];

        final results = _comparePair(a, b);
        comparisons.addAll(results);

        int aWins = 0;
        int bWins = 0;
        for (final r in results) {
          if (r.winner == a.playerIndex) {
            aWins++;
          } else if (r.winner == b.playerIndex) {
            bWins++;
          }
        }

        if (aWins == 3) {
          scores[a.playerIndex] = scores[a.playerIndex]! + 6;
          scores[b.playerIndex] = scores[b.playerIndex]! - 6;
        } else if (bWins == 3) {
          scores[b.playerIndex] = scores[b.playerIndex]! + 6;
          scores[a.playerIndex] = scores[a.playerIndex]! - 6;
        } else {
          scores[a.playerIndex] = scores[a.playerIndex]! + aWins - bWins;
          scores[b.playerIndex] = scores[b.playerIndex]! + bWins - aWins;
        }
      }
    }

    int? scoopWinner;
    for (final entry in scores.entries) {
      if (entry.value == (arrangements.length - 1) * 6) {
        scoopWinner = entry.key;
        break;
      }
    }

    return ScoringResult(
      scores: scores,
      comparisons: comparisons,
      scoopWinner: scoopWinner,
    );
  }

  /// Banker mode: every non-banker plays ONLY against the banker (not against
  /// each other). The banker's score is the negation of everyone else's.
  static ScoringResult calculateBankerScores(
    List<PlayerArrangement> arrangements,
    int bankerIndex,
  ) {
    final scores = <int, int>{};
    final comparisons = <ComparisonResult>[];
    for (final arr in arrangements) {
      scores[arr.playerIndex] = 0;
    }

    final banker = arrangements.firstWhere((a) => a.playerIndex == bankerIndex);

    for (final p in arrangements) {
      if (p.playerIndex == bankerIndex) continue;

      final results = _comparePair(p, banker);
      comparisons.addAll(results);

      int pWins = 0;
      int bWins = 0;
      for (final r in results) {
        if (r.winner == p.playerIndex) {
          pWins++;
        } else if (r.winner == bankerIndex) {
          bWins++;
        }
      }

      final int delta;
      if (pWins == 3) {
        delta = 6; // scooped the banker
      } else if (bWins == 3) {
        delta = -6; // banker scooped this player
      } else {
        delta = pWins - bWins;
      }

      scores[p.playerIndex] = scores[p.playerIndex]! + delta;
      scores[bankerIndex] = scores[bankerIndex]! - delta;
    }

    return ScoringResult(scores: scores, comparisons: comparisons);
  }

  static List<ComparisonResult> _comparePair(
    PlayerArrangement a,
    PlayerArrangement b,
  ) {
    return [
      _compareRow(a, b, 0, a.front, b.front),
      _compareRow(a, b, 1, a.middle, b.middle),
      _compareRow(a, b, 2, a.back, b.back),
    ];
  }

  static ComparisonResult _compareRow(
    PlayerArrangement a,
    PlayerArrangement b,
    int rowIndex,
    List<PlayingCard> hand1,
    List<PlayingCard> hand2,
  ) {
    final result1 = HandEvaluator.evaluate(hand1);
    final result2 = HandEvaluator.evaluate(hand2);
    final cmp = result1.compareTo(result2);

    return ComparisonResult(
      playerIndex: a.playerIndex,
      opponentIndex: b.playerIndex,
      rowIndex: rowIndex,
      winner: cmp > 0 ? a.playerIndex : (cmp < 0 ? b.playerIndex : -1),
      playerHand: result1,
      opponentHand: result2,
    );
  }
}
