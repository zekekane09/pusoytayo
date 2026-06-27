import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  OneToMany,
} from 'typeorm';
import { Wallet } from '../../wallet/entities/wallet.entity';
import { PlayerRanking } from '../../ranking/entities/player-ranking.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'firebase_uid', unique: true, length: 128 })
  firebaseUid: string;

  @Column({ name: 'display_name', length: 50 })
  displayName: string;

  @Column({ name: 'avatar_url', nullable: true, type: 'text' })
  avatarUrl: string | null;

  @Column({ name: 'auth_provider', length: 20 })
  authProvider: string;

  @Column({ name: 'phone_number', type: 'varchar', nullable: true, length: 20 })
  phoneNumber: string | null;

  @Column({ type: 'varchar', nullable: true, length: 255 })
  email: string | null;

  @Column({ name: 'is_guest', default: false })
  isGuest: boolean;

  @Column({ default: 'active', length: 20 })
  status: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToOne(() => Wallet, (wallet) => wallet.user)
  wallet: Wallet;

  @OneToOne(() => PlayerRanking, (ranking) => ranking.user)
  ranking: PlayerRanking;
}
