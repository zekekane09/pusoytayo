import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Wallet } from './wallet.entity';

@Entity('transactions')
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'wallet_id' })
  walletId: string;

  @Column({ length: 20 })
  type: string;

  @Column({ length: 10 })
  currency: string;

  @Column({ type: 'bigint' })
  amount: number;

  @Column({ name: 'balance_after', type: 'bigint' })
  balanceAfter: number;

  @Column({ name: 'reference_id', nullable: true, type: 'uuid' })
  referenceId: string | null;

  @Column({ nullable: true, type: 'text' })
  description: string | null;

  @Column({ default: 'completed', length: 20 })
  status: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => Wallet, (wallet) => wallet.transactions)
  @JoinColumn({ name: 'wallet_id' })
  wallet: Wallet;
}
