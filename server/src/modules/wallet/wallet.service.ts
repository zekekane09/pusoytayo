import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Wallet } from './entities/wallet.entity';
import { Transaction } from './entities/transaction.entity';

@Injectable()
export class WalletService {
  constructor(
    @InjectRepository(Wallet)
    private readonly walletRepo: Repository<Wallet>,
    @InjectRepository(Transaction)
    private readonly txRepo: Repository<Transaction>,
    private readonly dataSource: DataSource,
  ) {}

  async ensureWallet(
    userId: string,
    startingCoins = 1000,
    bonusLocked = 0,
  ): Promise<Wallet> {
    let wallet = await this.walletRepo.findOne({ where: { userId } });
    if (!wallet) {
      wallet = this.walletRepo.create({
        userId,
        coins: startingCoins,
        cash: 0,
        bonusLocked,
      });
      wallet = await this.walletRepo.save(wallet);

      await this.txRepo.save(
        this.txRepo.create({
          walletId: wallet.id,
          type: 'bonus',
          currency: 'coins',
          amount: startingCoins,
          balanceAfter: startingCoins,
          description: 'Welcome bonus',
        }),
      );
    }
    return wallet;
  }

  async getWallet(userId: string): Promise<Wallet> {
    const wallet = await this.walletRepo.findOne({ where: { userId } });
    if (!wallet) throw new NotFoundException('Wallet not found');
    return wallet;
  }

  async getTransactions(userId: string, limit = 50, offset = 0) {
    const wallet = await this.getWallet(userId);
    return this.txRepo.find({
      where: { walletId: wallet.id },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  async deductBet(
    userId: string,
    amount: number,
    currency: 'coins' | 'cash',
    gameId: string,
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const wallet = await manager.findOne(Wallet, {
        where: { userId },
        lock: { mode: 'pessimistic_write' },
      });

      if (!wallet) throw new NotFoundException('Wallet not found');

      const balance = currency === 'coins' ? wallet.coins : wallet.cash;
      if (balance < amount) {
        throw new BadRequestException('Insufficient balance');
      }

      if (currency === 'coins') {
        wallet.coins = Number(wallet.coins) - amount;
      } else {
        wallet.cash = Number(wallet.cash) - amount;
      }

      await manager.save(Wallet, wallet);

      const newBalance = currency === 'coins' ? wallet.coins : wallet.cash;
      await manager.save(
        Transaction,
        manager.create(Transaction, {
          walletId: wallet.id,
          type: 'bet',
          currency,
          amount: -amount,
          balanceAfter: newBalance,
          referenceId: gameId,
          description: 'Game bet',
        }),
      );
    });
  }

  async creditWinnings(
    userId: string,
    amount: number,
    currency: 'coins' | 'cash',
    gameId: string,
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const wallet = await manager.findOne(Wallet, {
        where: { userId },
        lock: { mode: 'pessimistic_write' },
      });

      if (!wallet) throw new NotFoundException('Wallet not found');

      if (currency === 'coins') {
        wallet.coins = Number(wallet.coins) + amount;
      } else {
        wallet.cash = Number(wallet.cash) + amount;
      }

      await manager.save(Wallet, wallet);

      const newBalance = currency === 'coins' ? wallet.coins : wallet.cash;
      await manager.save(
        Transaction,
        manager.create(Transaction, {
          walletId: wallet.id,
          type: 'win',
          currency,
          amount,
          balanceAfter: newBalance,
          referenceId: gameId,
          description: 'Game winnings',
        }),
      );
    });
  }

  /**
   * Apply a signed balance change in one transaction (positive credits,
   * negative debits). A debit is clamped to the available balance so a heavy
   * loss can never push the wallet negative. Returns the amount actually
   * applied. Used for banker-mode net settlement.
   */
  async settle(
    userId: string,
    delta: number,
    currency: 'coins' | 'cash',
    gameId: string | null,
  ): Promise<number> {
    if (delta === 0) return 0;
    return this.dataSource.transaction(async (manager) => {
      const wallet = await manager.findOne(Wallet, {
        where: { userId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException('Wallet not found');

      const balance = Number(currency === 'coins' ? wallet.coins : wallet.cash);
      const applied = delta < 0 ? -Math.min(balance, -delta) : delta;

      if (currency === 'coins') {
        wallet.coins = balance + applied;
      } else {
        wallet.cash = balance + applied;
      }
      await manager.save(Wallet, wallet);

      const newBalance = currency === 'coins' ? wallet.coins : wallet.cash;
      await manager.save(
        Transaction,
        manager.create(Transaction, {
          walletId: wallet.id,
          type: applied >= 0 ? 'win' : 'bet',
          currency,
          amount: applied,
          balanceAfter: newBalance,
          referenceId: gameId,
          description: 'Banker settlement',
        }),
      );
      return applied;
    });
  }
}
