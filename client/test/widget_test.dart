import 'package:flutter_test/flutter_test.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';

void main() {
  test('PlayingCard full deck has 52 cards', () {
    final deck = PlayingCard.fullDeck();
    expect(deck.length, 52);
  });

  test('PlayingCard sorts correctly', () {
    final cards = [
      const PlayingCard(rank: 15, suit: 'S'),
      const PlayingCard(rank: 3, suit: 'D'),
      const PlayingCard(rank: 14, suit: 'H'),
    ];
    cards.sort();
    expect(cards[0].rank, 3);
    expect(cards[1].rank, 14);
    expect(cards[2].rank, 15);
  });
}
