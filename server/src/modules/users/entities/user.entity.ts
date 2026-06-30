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

  @Column({
    name: 'username',
    type: 'varchar',
    nullable: true,
    unique: true,
    length: 32,
  })
  username: string | null;

  @Column({ name: 'password_hash', type: 'varchar', nullable: true, length: 100 })
  passwordHash: string | null;

  // The device that registered this account — used to grant the free sign-up
  // bonus only once per device.
  @Column({ name: 'device_id', type: 'varchar', nullable: true, length: 64 })
  deviceId: string | null;

  // IP the account registered from — a second guard against farming the free
  // bonus by clearing device storage (esp. on web).
  @Column({ name: 'signup_ip', type: 'varchar', nullable: true, length: 64 })
  signupIp: string | null;

  // Whether this account received the one-time free sign-up bonus.
  @Column({ name: 'bonus_claimed', default: false })
  bonusClaimed: boolean;

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
