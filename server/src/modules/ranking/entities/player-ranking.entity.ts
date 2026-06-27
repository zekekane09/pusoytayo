import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('player_rankings')
export class PlayerRanking {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', unique: true })
  userId: string;

  @Column({ name: 'rank_tier', default: 'Bronze', length: 30 })
  rankTier: string;

  @Column({ name: 'rank_points', default: 0 })
  rankPoints: number;

  @Column({ default: 0 })
  wins: number;

  @Column({ default: 0 })
  losses: number;

  @Column({ name: 'games_played', default: 0 })
  gamesPlayed: number;

  @Column({ name: 'win_streak', default: 0 })
  winStreak: number;

  @Column({ name: 'best_streak', default: 0 })
  bestStreak: number;

  @Column({ default: 1 })
  season: number;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToOne(() => User, (user) => user.ranking)
  @JoinColumn({ name: 'user_id' })
  user: User;
}
