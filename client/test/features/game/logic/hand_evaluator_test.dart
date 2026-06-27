import 'package:flutter_test/flutter_test.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';

PlayingCard c(int rank, String suit) => PlayingCard(rank: rank, suit: suit);

void main() {
  group('HandEvaluator', () {
    group('Singles', () {
      test('evaluates single card as high card', () {
        final result = HandEvaluator.evaluate([c(15, 'S')]);
        expect(result.type, HandType.highCard);
        expect(result.rankValues, [15]);
      });

      test('2 of Spades beats 2 of Hearts', () {
        final twoSpades = HandEvaluator.evaluate([c(15, 'S')]);
        final twoHearts = HandEvaluator.evaluate([c(15, 'H')]);
        expect(twoSpades.compareTo(twoHearts), greaterThan(0));
      });

      test('2 beats Ace', () {
        final two = HandEvaluator.evaluate([c(15, 'D')]);
        final ace = HandEvaluator.evaluate([c(14, 'S')]);
        expect(two.compareTo(ace), greaterThan(0));
      });

      test('Ace beats King', () {
        final ace = HandEvaluator.evaluate([c(14, 'S')]);
        final king = HandEvaluator.evaluate([c(13, 'S')]);
        expect(ace.compareTo(king), greaterThan(0));
      });
    });

    group('Pairs', () {
      test('detects pair', () {
        final result = HandEvaluator.evaluate([c(10, 'H'), c(10, 'S')]);
        expect(result.type, HandType.pair);
      });

      test('pair of 2s beats pair of Aces', () {
        final twos = HandEvaluator.evaluate([c(15, 'H'), c(15, 'S')]);
        final aces = HandEvaluator.evaluate([c(14, 'H'), c(14, 'S')]);
        expect(twos.compareTo(aces), greaterThan(0));
      });

      test('same rank pair: higher suit wins', () {
        final spadesHearts = HandEvaluator.evaluate([c(10, 'H'), c(10, 'S')]);
        final clubsDiamonds = HandEvaluator.evaluate([c(10, 'D'), c(10, 'C')]);
        expect(spadesHearts.compareTo(clubsDiamonds), greaterThan(0));
      });
    });

    group('Three of a Kind', () {
      test('detects three of a kind', () {
        final result = HandEvaluator.evaluate([c(7, 'H'), c(7, 'S'), c(7, 'D')]);
        expect(result.type, HandType.threeOfAKind);
      });
    });

    group('Five-card hands', () {
      test('detects straight', () {
        final result = HandEvaluator.evaluate([
          c(5, 'H'), c(6, 'D'), c(7, 'S'), c(8, 'C'), c(9, 'H'),
        ]);
        expect(result.type, HandType.straight);
      });

      test('detects flush', () {
        final result = HandEvaluator.evaluate([
          c(3, 'H'), c(6, 'H'), c(9, 'H'), c(11, 'H'), c(13, 'H'),
        ]);
        expect(result.type, HandType.flush);
      });

      test('detects full house', () {
        final result = HandEvaluator.evaluate([
          c(8, 'H'), c(8, 'S'), c(8, 'D'), c(12, 'H'), c(12, 'S'),
        ]);
        expect(result.type, HandType.fullHouse);
        expect(result.rankValues[0], 8);
      });

      test('detects four of a kind', () {
        final result = HandEvaluator.evaluate([
          c(9, 'H'), c(9, 'S'), c(9, 'D'), c(9, 'C'), c(5, 'H'),
        ]);
        expect(result.type, HandType.fourOfAKind);
      });

      test('detects straight flush', () {
        final result = HandEvaluator.evaluate([
          c(5, 'H'), c(6, 'H'), c(7, 'H'), c(8, 'H'), c(9, 'H'),
        ]);
        expect(result.type, HandType.straightFlush);
      });

      test('detects royal flush', () {
        final result = HandEvaluator.evaluate([
          c(10, 'S'), c(11, 'S'), c(12, 'S'), c(13, 'S'), c(14, 'S'),
        ]);
        expect(result.type, HandType.royalFlush);
      });
    });

    group('Hand ranking comparison', () {
      test('straight flush beats four of a kind', () {
        final sf = HandEvaluator.evaluate([
          c(5, 'H'), c(6, 'H'), c(7, 'H'), c(8, 'H'), c(9, 'H'),
        ]);
        final foak = HandEvaluator.evaluate([
          c(14, 'H'), c(14, 'S'), c(14, 'D'), c(14, 'C'), c(13, 'H'),
        ]);
        expect(sf.compareTo(foak), greaterThan(0));
      });

      test('four of a kind beats full house', () {
        final foak = HandEvaluator.evaluate([
          c(9, 'H'), c(9, 'S'), c(9, 'D'), c(9, 'C'), c(5, 'H'),
        ]);
        final fh = HandEvaluator.evaluate([
          c(14, 'H'), c(14, 'S'), c(14, 'D'), c(13, 'H'), c(13, 'S'),
        ]);
        expect(foak.compareTo(fh), greaterThan(0));
      });

      test('full house beats flush', () {
        final fh = HandEvaluator.evaluate([
          c(3, 'H'), c(3, 'S'), c(3, 'D'), c(4, 'H'), c(4, 'S'),
        ]);
        final flush = HandEvaluator.evaluate([
          c(3, 'S'), c(6, 'S'), c(9, 'S'), c(11, 'S'), c(14, 'S'),
        ]);
        expect(fh.compareTo(flush), greaterThan(0));
      });

      test('flush beats straight', () {
        final flush = HandEvaluator.evaluate([
          c(3, 'H'), c(6, 'H'), c(9, 'H'), c(11, 'H'), c(13, 'H'),
        ]);
        final straight = HandEvaluator.evaluate([
          c(10, 'H'), c(11, 'D'), c(12, 'S'), c(13, 'C'), c(14, 'H'),
        ]);
        expect(flush.compareTo(straight), greaterThan(0));
      });
    });

    group('Arrangement validation', () {
      test('valid arrangement: back > middle > front', () {
        final front = [c(3, 'H'), c(4, 'S'), c(5, 'D')];
        final middle = [c(8, 'H'), c(8, 'S'), c(8, 'D'), c(12, 'H'), c(12, 'S')];
        final back = [c(9, 'H'), c(9, 'S'), c(9, 'D'), c(9, 'C'), c(5, 'H')];
        expect(HandEvaluator.isValidArrangement(front, middle, back), true);
      });

      test('invalid arrangement: middle stronger than back', () {
        final front = [c(3, 'H'), c(4, 'S'), c(5, 'D')];
        final middle = [c(14, 'H'), c(14, 'S'), c(14, 'D'), c(14, 'C'), c(13, 'H')];
        final back = [c(6, 'H'), c(7, 'D'), c(8, 'S'), c(9, 'C'), c(10, 'H')];
        expect(HandEvaluator.isValidArrangement(front, middle, back), false);
      });

      test('rejects wrong card counts', () {
        final front = [c(3, 'H'), c(4, 'S')];
        final middle = [c(8, 'H'), c(8, 'S'), c(8, 'D'), c(12, 'H'), c(12, 'S')];
        final back = [c(9, 'H'), c(9, 'S'), c(9, 'D'), c(9, 'C'), c(5, 'H')];
        expect(HandEvaluator.isValidArrangement(front, middle, back), false);
      });
    });
  });
}
