import { Injectable } from '@nestjs/common';

export interface Card {
  rank: number;
  suit: 'S' | 'H' | 'D' | 'C';
}

export enum HandType {
  HIGH_CARD = 0,
  PAIR = 1,
  TWO_PAIR = 2,
  THREE_OF_A_KIND = 3,
  STRAIGHT = 4,
  FLUSH = 5,
  FULL_HOUSE = 6,
  FOUR_OF_A_KIND = 7,
  STRAIGHT_FLUSH = 8,
  ROYAL_FLUSH = 9,
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

  /**
   * Auto-arrange 13 cards into a legal 3/5/5 split (weakest in front), used as
   * a fallback for players who didn't submit before the timer expired.
   */
  autoArrange(cards: Card[]): { front: Card[]; middle: Card[]; back: Card[] } {
    const sorted = [...cards].sort((a, b) => a.rank - b.rank);
    const front = sorted.slice(0, 3);
    let middle = sorted.slice(3, 8);
    let back = sorted.slice(8, 13);
    // Ensure back >= middle so the arrangement is valid.
    if (this.compareHands(this.evaluate(middle), this.evaluate(back)) > 0) {
      const t = middle;
      middle = back;
      back = t;
    }
    return { front, middle, back };
  }

  evaluate(cards: Card[]): HandResult {
    // Standard poker ranking: 2 is the LOWEST card. The deck stores "2" as
    // rank 15, so normalize it to 2 before evaluating/comparing anything.
    const norm = cards.map((c) => ({
      rank: c.rank === 15 ? 2 : c.rank,
      suit: c.suit,
    }));
    const sorted = [...norm].sort((a, b) => {
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
      const ranks = sorted.map((c) => c.rank).sort((a, b) => b - a);
      const counts = this.countRanks(sorted);
      const maxSuit = Math.max(...sorted.map((c) => SUIT_ORDER[c.suit]));

      if (Object.values(counts).some((v) => v === 3)) {
        return {
          type: HandType.THREE_OF_A_KIND,
          rankValues: [ranks[0]],
          highSuitValue: maxSuit,
        };
      }

      const pairRank = Object.keys(counts).find((r) => counts[r] === 2);
      if (pairRank) {
        const pr = parseInt(pairRank);
        const kicker = ranks.find((r) => r !== pr)!;
        return {
          type: HandType.PAIR,
          rankValues: [pr, kicker],
          highSuitValue: Math.max(
            ...sorted
              .filter((c) => c.rank === pr)
              .map((c) => SUIT_ORDER[c.suit]),
          ),
        };
      }

      return {
        type: HandType.HIGH_CARD,
        rankValues: ranks,
        highSuitValue: maxSuit,
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
    const isStraight = this.isStraightCards(sorted);

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
          rankValues: [this.straightHigh(sorted)],
          highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
        };
      }
      return {
        type: HandType.STRAIGHT_FLUSH,
        rankValues: [this.straightHigh(sorted)],
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
        rankValues: [this.straightHigh(sorted)],
        highSuitValue: SUIT_ORDER[sorted[sorted.length - 1].suit],
      };
    }

    const maxSuitOf = (rank: number) =>
      Math.max(
        ...sorted.filter((c) => c.rank === rank).map((c) => SUIT_ORDER[c.suit]),
      );
    const desc = [...sorted.map((c) => c.rank)].sort((a, b) => b - a);

    const tripRank = Object.keys(counts).find((r) => counts[r] === 3);
    if (tripRank) {
      const tr = parseInt(tripRank);
      return {
        type: HandType.THREE_OF_A_KIND,
        rankValues: [tr, ...desc.filter((r) => r !== tr)],
        highSuitValue: maxSuitOf(tr),
      };
    }

    const pairRanks = Object.keys(counts)
      .filter((r) => counts[r] === 2)
      .map((r) => parseInt(r))
      .sort((a, b) => b - a);
    if (pairRanks.length >= 2) {
      const [high, low] = pairRanks;
      const kicker = desc.find((r) => r !== high && r !== low)!;
      return {
        type: HandType.TWO_PAIR,
        rankValues: [high, low, kicker],
        highSuitValue: maxSuitOf(high),
      };
    }
    if (pairRanks.length === 1) {
      const pr = pairRanks[0];
      return {
        type: HandType.PAIR,
        rankValues: [pr, ...desc.filter((r) => r !== pr)],
        highSuitValue: maxSuitOf(pr),
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

  /**
   * Straights use the natural poker order where "2" is LOW (2-3-4-5-6 is a
   * straight), even though 2 is the highest card otherwise. The deck stores
   * "2" as rank 15, so map it back to 2 for sequence checks. Also supports the
   * Ace-low wheel (A-2-3-4-5).
   */
  private straightValues(cards: Card[]): number[] {
    return cards.map((c) => (c.rank === 15 ? 2 : c.rank)).sort((a, b) => a - b);
  }

  private isStraightCards(cards: Card[]): boolean {
    const v = this.straightValues(cards);
    if (this.checkStraight(v)) return true;
    if (v.includes(14)) {
      const w = v.map((x) => (x === 14 ? 1 : x)).sort((a, b) => a - b);
      if (this.checkStraight(w)) return true;
    }
    return false;
  }

  private straightHigh(cards: Card[]): number {
    const v = this.straightValues(cards);
    if (this.checkStraight(v)) return v[v.length - 1];
    if (v.includes(14)) {
      const w = v.map((x) => (x === 14 ? 1 : x)).sort((a, b) => a - b);
      if (this.checkStraight(w)) return w[w.length - 1];
    }
    return v[v.length - 1];
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

  /**
   * Banker mode: every player is scored only against the banker (head-to-head).
   * The banker's score is the mirror of the sum of everyone else's results.
   * A 3-row sweep ("scoop") is worth 6, otherwise +1 per row won, -1 per lost.
   */
  /**
   * A "LOCKED" hand is a special auto-win: the arrangement contains BOTH a
   * straight flush (or royal flush) AND a four-of-a-kind across its two 5-card
   * rows (middle + back). A locked player beats any non-locked opponent
   * outright; if both sides are locked it's a tie.
   */
  isLocked(_front: Card[], middle: Card[], back: Card[]): boolean {
    const types = [this.evaluate(middle).type, this.evaluate(back).type];
    const hasStraightFlush = types.some(
      (t) => t === HandType.STRAIGHT_FLUSH || t === HandType.ROYAL_FLUSH,
    );
    const hasFourKind = types.some((t) => t === HandType.FOUR_OF_A_KIND);
    return hasStraightFlush && hasFourKind;
  }

  calculateBankerScores(
    arrangements: {
      playerId: string;
      front: Card[];
      middle: Card[];
      back: Card[];
    }[],
    bankerId: string,
  ): Record<string, number> {
    const scores: Record<string, number> = {};
    for (const a of arrangements) scores[a.playerId] = 0;

    const banker = arrangements.find((a) => a.playerId === bankerId);
    if (!banker) return scores;

    const bankerLocked = this.isLocked(banker.front, banker.middle, banker.back);

    for (const p of arrangements) {
      if (p.playerId === bankerId) continue;

      const playerLocked = this.isLocked(p.front, p.middle, p.back);

      let delta: number;
      // LOCKED overrides the normal row-by-row comparison.
      if (playerLocked || bankerLocked) {
        if (playerLocked && bankerLocked) {
          delta = 0; // both locked → tie
        } else if (playerLocked) {
          delta = 6; // player's locked hand auto-wins
        } else {
          delta = -6; // banker's locked hand auto-wins
        }
      } else {
        let pWins = 0;
        let bWins = 0;
        const rows: [Card[], Card[]][] = [
          [p.front, banker.front],
          [p.middle, banker.middle],
          [p.back, banker.back],
        ];
        for (const [hp, hb] of rows) {
          const cmp = this.compareHands(this.evaluate(hp), this.evaluate(hb));
          if (cmp > 0) pWins++;
          else if (cmp < 0) bWins++;
        }
        if (pWins === 3) delta = 6;
        else if (bWins === 3) delta = -6;
        else delta = pWins - bWins;
      }

      scores[p.playerId] += delta;
      scores[bankerId] -= delta;
    }

    return scores;
  }

  /** Single-row winner across all players. Returns null when the row is tied. */
  rowWinner(hands: { playerId: string; cards: Card[] }[]): string | null {
    if (hands.length === 0) return null;
    let best = this.evaluate(hands[0].cards);
    for (const h of hands) {
      const r = this.evaluate(h.cards);
      if (this.compareHands(r, best) > 0) best = r;
    }
    const top = hands.filter(
      (h) => this.compareHands(this.evaluate(h.cards), best) === 0,
    );
    return top.length === 1 ? top[0].playerId : null;
  }

  /**
   * Central Pot mode: every player antes `bet` into a shared pot. The pot is
   * split into three equal row shares awarded to each row's winner. Tied rows
   * are refunded equally to every player. Returns the net chip change per
   * player (already net of the ante) plus the per-row winners for the reveal.
   */
  calculatePotDistribution(
    arrangements: {
      playerId: string;
      front: Card[];
      middle: Card[];
      back: Card[];
    }[],
    bet: number | Record<string, number>,
  ): {
    net: Record<string, number>;
    pot: number;
    rowWinners: { front: string | null; middle: string | null; back: string | null };
  } {
    const n = arrangements.length;
    // Antes may be a single flat bet for everyone, or a per-player map (each
    // player chose their own bet in the betting phase).
    const ante = (id: string): number =>
      typeof bet === 'number' ? bet : bet[id] || 0;
    const pot = arrangements.reduce((sum, a) => sum + ante(a.playerId), 0);
    // Integer chips only — floor the per-row share and refund the remainder so
    // the pot is conserved exactly without producing fractional scores.
    const share = Math.floor(pot / 3);

    const net: Record<string, number> = {};
    for (const a of arrangements) net[a.playerId] = -ante(a.playerId);

    const rowWinners = {
      front: this.rowWinner(
        arrangements.map((a) => ({ playerId: a.playerId, cards: a.front })),
      ),
      middle: this.rowWinner(
        arrangements.map((a) => ({ playerId: a.playerId, cards: a.middle })),
      ),
      back: this.rowWinner(
        arrangements.map((a) => ({ playerId: a.playerId, cards: a.back })),
      ),
    };

    let distributed = 0;
    for (const w of [rowWinners.front, rowWinners.middle, rowWinners.back]) {
      if (w) {
        net[w] += share;
        distributed += share;
      }
    }

    // Whatever is left (flooring remainders + tied rows) is refunded as evenly
    // as possible, with any final odd chips handed out one at a time.
    let remainder = pot - distributed;
    if (remainder > 0 && n > 0) {
      const each = Math.floor(remainder / n);
      for (const a of arrangements) {
        net[a.playerId] += each;
        remainder -= each;
      }
      for (let i = 0; i < arrangements.length && remainder > 0; i++) {
        net[arrangements[i].playerId] += 1;
        remainder--;
      }
    }

    return { net, pot, rowWinners };
  }
}
