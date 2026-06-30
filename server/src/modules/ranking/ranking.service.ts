import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlayerRanking } from './entities/player-ranking.entity';

const RANK_TIERS = [
  { name: 'Bronze', minPoints: 0, maxPoints: 999, winBonus: 25, lossPenalty: 10 },
  { name: 'Silver', minPoints: 1000, maxPoints: 2499, winBonus: 20, lossPenalty: 12 },
  { name: 'Gold', minPoints: 2500, maxPoints: 4999, winBonus: 18, lossPenalty: 15 },
  { name: 'Platinum', minPoints: 5000, maxPoints: 7999, winBonus: 15, lossPenalty: 15 },
  { name: 'Diamond', minPoints: 8000, maxPoints: 11999, winBonus: 12, lossPenalty: 18 },
  { name: 'Legend', minPoints: 12000, maxPoints: Infinity, winBonus: 10, lossPenalty: 20 },
];

@Injectable()
export class RankingService {
  constructor(
    @InjectRepository(PlayerRanking)
    private readonly rankRepo: Repository<PlayerRanking>,
  ) {}

  async ensureRanking(userId: string): Promise<PlayerRanking> {
    let ranking = await this.rankRepo.findOne({ where: { userId } });
    if (!ranking) {
      ranking = this.rankRepo.create({ userId });
      ranking = await this.rankRepo.save(ranking);
    }
    return ranking;
  }

  async updateRanking(userId: string, won: boolean): Promise<PlayerRanking> {
    const ranking = await this.ensureRanking(userId);

    const tier = RANK_TIERS.find(
      (t) => ranking.rankPoints >= t.minPoints && ranking.rankPoints <= t.maxPoints,
    ) || RANK_TIERS[0];

    ranking.gamesPlayed++;

    if (won) {
      ranking.wins++;
      ranking.winStreak++;
      ranking.bestStreak = Math.max(ranking.bestStreak, ranking.winStreak);
      ranking.rankPoints += tier.winBonus;
    } else {
      ranking.losses++;
      ranking.winStreak = 0;
      ranking.rankPoints = Math.max(0, ranking.rankPoints - tier.lossPenalty);
    }

    const newTier = RANK_TIERS.find(
      (t) => ranking.rankPoints >= t.minPoints && ranking.rankPoints <= t.maxPoints,
    ) || RANK_TIERS[0];

    ranking.rankTier = newTier.name;

    return this.rankRepo.save(ranking);
  }

  async getRanking(userId: string): Promise<PlayerRanking | null> {
    return this.rankRepo.findOne({ where: { userId } });
  }

  /** Recompute the tier name for the current rank points. */
  private tierFor(points: number): string {
    return (
      RANK_TIERS.find((t) => points >= t.minPoints && points <= t.maxPoints) ||
      RANK_TIERS[0]
    ).name;
  }

  /**
   * Award rank points for placing a bet — the tier climbs the more a player
   * wagers (1 rank point per coin bet). Also tracks lifetime wagered.
   */
  async addWager(userId: string, bet: number): Promise<void> {
    const amt = Math.floor(Number(bet) || 0);
    if (amt <= 0) return;
    const ranking = await this.ensureRanking(userId);
    ranking.totalWagered = Number(ranking.totalWagered) + amt;
    ranking.rankPoints += amt;
    ranking.rankTier = this.tierFor(ranking.rankPoints);
    await this.rankRepo.save(ranking);
  }

  /** Record a single-deal win; keeps the player's all-time best. */
  async recordWin(userId: string, coinsWon: number): Promise<void> {
    const won = Math.floor(Number(coinsWon) || 0);
    if (won <= 0) return;
    const ranking = await this.ensureRanking(userId);
    if (won > Number(ranking.highestWin)) {
      ranking.highestWin = won;
      await this.rankRepo.save(ranking);
    }
  }

  async getLeaderboard(limit = 100): Promise<PlayerRanking[]> {
    return this.rankRepo.find({
      order: { rankPoints: 'DESC' },
      take: limit,
      relations: ['user'],
    });
  }

  /** Leaderboard ranked by the biggest single-deal win. */
  async getTopWins(limit = 100): Promise<PlayerRanking[]> {
    return this.rankRepo.find({
      where: {},
      order: { highestWin: 'DESC' },
      take: limit,
      relations: ['user'],
    });
  }
}
