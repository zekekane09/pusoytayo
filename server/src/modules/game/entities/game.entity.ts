import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('games')
export class Game {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'room_code', unique: true, length: 10 })
  roomCode: string;

  @Column({ default: 'waiting', length: 20 })
  status: string;

  @Column({ name: 'game_mode', default: 'classic', length: 20 })
  gameMode: string;

  @Column({ name: 'bet_amount', type: 'bigint', default: 0 })
  betAmount: number;

  @Column({ default: 'coins', length: 10 })
  currency: string;

  @Column({ name: 'max_players', default: 4 })
  maxPlayers: number;

  @Column({ name: 'created_by', nullable: true })
  createdBy: string;

  @Column({ name: 'winner_id', type: 'uuid', nullable: true })
  winnerId: string | null;

  @Column({ name: 'started_at', type: 'timestamp', nullable: true })
  startedAt: Date | null;

  @Column({ name: 'finished_at', type: 'timestamp', nullable: true })
  finishedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'created_by' })
  creator: User;

  @OneToMany(() => GamePlayer, (gp) => gp.game)
  players: GamePlayer[];
}

@Entity('game_players')
export class GamePlayer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'game_id' })
  gameId: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column()
  seat: number;

  @Column({ name: 'cards_json', type: 'jsonb', nullable: true })
  cardsJson: any;

  @Column({ name: 'front_hand', type: 'jsonb', nullable: true })
  frontHand: any;

  @Column({ name: 'middle_hand', type: 'jsonb', nullable: true })
  middleHand: any;

  @Column({ name: 'back_hand', type: 'jsonb', nullable: true })
  backHand: any;

  @Column({ default: 0 })
  score: number;

  @Column({ name: 'is_ready', default: false })
  isReady: boolean;

  @Column({ name: 'joined_at', type: 'timestamp', default: () => 'NOW()' })
  joinedAt: Date;

  @ManyToOne(() => Game, (game) => game.players)
  @JoinColumn({ name: 'game_id' })
  game: Game;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;
}
