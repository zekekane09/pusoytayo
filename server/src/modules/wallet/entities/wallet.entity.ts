import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Transaction } from './transaction.entity';

@Entity('wallets')
export class Wallet {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', unique: true })
  userId: string;

  @Column({ type: 'bigint', default: 1000 })
  coins: number;

  @Column({ type: 'bigint', default: 0 })
  cash: number;

  // Coins that can't be withdrawn until wagered & won (e.g. the free sign-up
  // bonus). Withdrawable = max(0, coins - bonusLocked).
  @Column({ name: 'bonus_locked', type: 'bigint', default: 0 })
  bonusLocked: number;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToOne(() => User, (user) => user.wallet)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => Transaction, (tx) => tx.wallet)
  transactions: Transaction[];
}
