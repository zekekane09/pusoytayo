import { Injectable } from '@nestjs/common';

export interface Card {
  rank: number;
  suit: 'S' | 'H' | 'D' | 'C';
}

export enum HandType {
  HIGH_CARD = 0,
  PAIR = 1,
  THREE_OF_A_KIND = 2,
  STRAIGHT = 3,
  FLUSH = 4,
  FULL_HOUSE = 5,
  FOUR_OF_A_KIND = 6,
  STRAIGHT_FLUSH = 7,
  ROYAL_FLUSH = 8,
}

export interface HandResult {
  type: HandType;
  rankValues: number[];
  highSuitValue: number;
}

const SUIT_ORDER: Record<string, number> = { D: 0, C: 1, H: 2, S: 3 };

@Injectable()
export class GameLogicService {
  createDeck(): Card[] {
    const suits: Card['suit'][] = ['D', 'C', 'H', 'S'];
    const deck: Card[] = [];
    for (const suit of suits) {
      for (let rank = 3; rank <= 15; rank++) {
        deck.push({ rank, suit });
      }
    }
    return deck;
  }

  shuffleDeck(deck: Card[]): Card[] {
    const shuffled = [...deck];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  dealCards(playerCount: number): Card[][] {
    const deck = this.shuffleDeck(this.createDeck());
    const hands: Card[][] = [];
    for (let i = 0; i < playerCount; i++) {
      hands.push(deck.slice(i * 13, (i + 1) * 13));
    }
    return hands;
  }

  evaluate(cards: Card[]): HandResult {
    const sorted = [...cards].sort((a, b) => {
      if (a.rank !== b.rank) return a.rank - b.rank;
      return SUIT_ORDER[a.suit] - SUIT_ORDER[b.suit];
    });

    if (cards.length === 1) {
      return {
        type: HandType.HIGH_CARD,
        rankValues: [sorted[0].rank],
        highSuitValue: SUIT_ORDER[sorted[0].suit],
      };
    }

    if (cards.length === 2) {
      if (sorted[0].rank === sorted[1].rank) {
        return {
          type: HandType.PAIR,
          rankValues: [sorted[0].rank],
          highSuitValue: Math.max(
            SUIT_ORDER[sorted[0].suit],
            SUIT_ORDER[sorted[1].suit],
          ),
        };
      }
      return {
        type: HandType.HIGH_CARD,
        rankValues: sorted
          .map((c) => c.rank)
          .sort((a, b) => b - a),
        highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
      };
    }

    if (cards.length === 3) {
      const ranks = sorted.map((c) => c.rank);
      if (new Set(ranks).size === 1) {
        return {
          type: HandType.THREE_OF_A_KIND,
          rankValues: [ranks[0]],
          highSuitValue: Math.max(
            ...sorted.map((c) => SUIT_ORDER[c.suit]),
          ),
        };
      }
      return {
        type: HandType.HIGH_CARD,
        rankValues: ranks.sort((a, b) => b - a),
        highSuitValue: Math.max(
          ...sorted.map((c) => SUIT_ORDER[c.suit]),
        ),
      };
    }

    if (cards.length === 5) {
      return this.evaluateFive(sorted);
    }

    return {
      type: HandType.HIGH_CARD,
      rankValues: sorted
        .map((c) => c.rank)
        .sort((a, b) => b - a),
      highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
    };
  }

  private evaluateFive(sorted: Card[]): HandResult {
    const isFlush = sorted.every((c) => c.suit === sorted[0].suit);
    const ranks = sorted.map((c) => c.rank);
    const isStraight = this.checkStraight(ranks);

    if (isFlush && isStraight) {
      if (
        ranks.includes(14) &&
        ranks.includes(13) &&
        ranks.includes(12) &&
        ranks.includes(11) &&
        ranks.includes(10)
      ) {
        return {
          type: HandType.ROYAL_FLUSH,
          rankValues: [sorted[sorted.length - 1].rank],
          highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
        };
      }
      return {
        type: HandType.STRAIGHT_FLUSH,
        rankValues: [sorted[sorted.length - 1].rank],
        highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
      };
    }

    const counts = this.countRanks(sorted);

    const fourRank = Object.entries(counts).find(([, v]) => v === 4);
    if (fourRank) {
      const kicker = Object.keys(counts).find((r) => r !== fourRank[0]);
      return {
        type: HandType.FOUR_OF_A_KIND,
        rankValues: [parseInt(fourRank[0]), parseInt(kicker!)],
        highSuitValue: Math.max(
          ...sorted
            .filter((c) => c.rank === parseInt(fourRank[0]))
            .map((c) => SUIT_ORDER[c.suit]),
        ),
      };
    }

    const threeRank = Object.entries(counts).find(([, v]) => v === 3);
    const twoRank = Object.entries(counts).find(([, v]) => v === 2);

    if (threeRank && twoRank) {
      return {
        type: HandType.FULL_HOUSE,
        rankValues: [parseInt(threeRank[0]), parseInt(twoRank[0])],
        highSuitValue: Math.max(
          ...sorted
            .filter((c) => c.rank === parseInt(threeRank[0]))
            .map((c) => SUIT_ORDER[c.suit]),
        ),
      };
    }

    if (isFlush) {
      return {
        type: HandType.FLUSH,
        rankValues: ranks.sort((a, b) => b - a),
        highSuitValue: SUIT_ORDER[sorted[0].suit],
      };
    }

    if (isStraight) {
      return {
        type: HandType.STRAIGHT,
        rankValues: [sorted[sorted.length - 1].rank],
        highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
      };
    }

    return {
      type: HandType.HIGH_CARD,
      rankValues: ranks.sort((a, b) => b - a),
      highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
    };
  }

  private checkStraight(ranks: number[]): boolean {
    const sorted = [...ranks].sort((a, b) => a - b);
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] !== 1) return false;
    }
    return true;
  }

  private countRanks(cards: Card[]): Record<string, number> {
    const counts: Record<string, number> = {};
    for (const card of cards) {
      counts[card.rank] = (counts[card.rank] || 0) + 1;
    }
    return counts;
  }

  compareHands(a: HandResult, b: HandResult): number {
    if (a.type !== b.type) return a.type - b.type;
    for (let i = 0; i < a.rankValues.length && i < b.rankValues.length; i++) {
      if (a.rankValues[i] !== b.rankValues[i]) {
        return a.rankValues[i] - b.rankValues[i];
      }
    }
    return a.highSuitValue - b.highSuitValue;
  }

  validateArrangement(
    front: Card[],
    middle: Card[],
    back: Card[],
  ): boolean {
    if (front.length !== 3 || middle.length !== 5 || back.length !== 5) {
      return false;
    }

    const frontResult = this.evaluate(front);
    const middleResult = this.evaluate(middle);
    const backResult = this.evaluate(back);

    return (
      this.compareHands(middleResult, frontResult) >= 0 &&
      this.compareHands(backResult, middleResult) >= 0
    );
  }

  calculateScores(
    arrangements: {
      playerId: string;
      front: Card[];
      middle: Card[];
      back: Card[];
    }[],
  ): Record<string, number> {
    const scores: Record<string, number> = {};
    for (const a of arrangements) {
      scores[a.playerId] = 0;
    }

    for (let i = 0; i < arrangements.length; i++) {
      for (let j = i + 1; j < arrangements.length; j++) {
        const a = arrangements[i];
        const b = arrangements[j];

        let aWins = 0;
        let bWins = 0;

        const rows: [Card[], Card[]][] = [
          [a.front, b.front],
          [a.middle, b.middle],
          [a.back, b.back],
        ];

        for (const [handA, handB] of rows) {
          const cmp = this.compareHands(
            this.evaluate(handA),
            this.evaluate(handB),
          );
          if (cmp > 0) aWins++;
          else if (cmp < 0) bWins++;
        }

        if (aWins === 3) {
          scores[a.playerId] += 6;
          scores[b.playerId] -= 6;
        } else if (bWins === 3) {
          scores[b.playerId] += 6;
          scores[a.playerId] -= 6;
        } else {
          scores[a.playerId] += aWins - bWins;
          scores[b.playerId] += bWins - aWins;
        }
      }
    }

    return scores;
  }
}
