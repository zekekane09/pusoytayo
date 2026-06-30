import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Wallet } from './entities/wallet.entity';
import { Transaction } from './entities/transaction.entity';
import { Withdrawal } from './entities/withdrawal.entity';
import { Deposit } from './entities/deposit.entity';

@Injectable()
export class WalletService {
  constructor(
    @InjectRepository(Wallet)
    private readonly walletRepo: Repository<Wallet>,
    @InjectRepository(Transaction)
    private readonly txRepo: Repository<Transaction>,
    @InjectRepository(Withdrawal)
    private readonly withdrawalRepo: Repository<Withdrawal>,
    @InjectRepository(Deposit)
    private readonly depositRepo: Repository<Deposit>,
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

  // ── Withdrawals ──────────────────────────────────────────────────────────

  /** Coins that can actually be cashed out (won money, not the locked bonus). */
  withdrawableOf(w: Wallet): number {
    return Math.max(0, Number(w.coins) - Number(w.bonusLocked || 0));
  }

  /** Create a pending withdrawal; the coins are held (deducted) immediately. */
  async requestWithdrawal(
    userId: string,
    userName: string,
    amount: number,
    gcashNumber: string,
    gcashName: string,
  ): Promise<Withdrawal> {
    const amt = Math.floor(Number(amount) || 0);
    if (amt < 100) {
      throw new BadRequestException('Minimum withdrawal is 100 coins');
    }
    if (!gcashNumber || !gcashName) {
      throw new BadRequestException('GCash number and name are required');
    }
    return this.dataSource.transaction(async (manager) => {
      const wallet = await manager.findOne(Wallet, {
        where: { userId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException('Wallet not found');
      const withdrawable = this.withdrawableOf(wallet);
      if (amt > withdrawable) {
        throw new BadRequestException(
          `You can only withdraw winnings. Withdrawable: ${withdrawable}`,
        );
      }
      wallet.coins = Number(wallet.coins) - amt;
      await manager.save(Wallet, wallet);
      await manager.save(
        Transaction,
        manager.create(Transaction, {
          walletId: wallet.id,
          type: 'withdraw',
          currency: 'coins',
          amount: -amt,
          balanceAfter: wallet.coins,
          description: `Withdrawal request to GCash ${gcashNumber}`,
        }),
      );
      // Processing fee: 5 coins per 500 (≈ 1%). Player receives amount - fee.
      const fee = Math.floor(amt / 100);
      return manager.save(
        Withdrawal,
        manager.create(Withdrawal, {
          userId,
          userName,
          amount: amt,
          fee,
          gcashNumber,
          gcashName,
          status: 'pending',
        }),
      );
    });
  }

  async userWithdrawals(userId: string): Promise<Withdrawal[]> {
    return this.withdrawalRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async allWithdrawals(status?: string): Promise<Withdrawal[]> {
    return this.withdrawalRepo.find({
      where: status ? { status } : {},
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  /** Admin approve/reject. Rejecting refunds the held coins. */
  async processWithdrawal(
    id: string,
    action: 'approve' | 'reject',
    note?: string,
  ): Promise<Withdrawal> {
    const wd = await this.withdrawalRepo.findOne({ where: { id } });
    if (!wd) throw new NotFoundException('Withdrawal not found');
    if (wd.status !== 'pending') {
      throw new BadRequestException('Already processed');
    }
    if (action === 'reject') {
      // Refund the held coins.
      await this.settle(wd.userId, Number(wd.amount), 'coins', null);
      wd.status = 'rejected';
    } else {
      wd.status = 'approved';
    }
    wd.note = note ?? null;
    wd.processedAt = new Date();
    return this.withdrawalRepo.save(wd);
  }

  // ── Deposits (manual GCash top-up) ────────────────────────────────────────

  /** Player submits a top-up request with their GCash reference number. No
   * coins are added until the admin verifies the payment and approves. */
  async requestDeposit(
    userId: string,
    userName: string,
    amount: number,
    gcashRef: string,
  ): Promise<Deposit> {
    const amt = Math.floor(Number(amount) || 0);
    if (amt < 20) {
      throw new BadRequestException('Minimum deposit is 20 coins');
    }
    if (!gcashRef || gcashRef.trim().length < 4) {
      throw new BadRequestException('A valid GCash reference number is required');
    }
    return this.depositRepo.save(
      this.depositRepo.create({
        userId,
        userName,
        amount: amt,
        gcashRef: gcashRef.trim(),
        status: 'pending',
      }),
    );
  }

  async userDeposits(userId: string): Promise<Deposit[]> {
    return this.depositRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async allDeposits(status?: string): Promise<Deposit[]> {
    return this.depositRepo.find({
      where: status ? { status } : {},
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  /** Admin approve (credits the coins) / reject a deposit. */
  async processDeposit(
    id: string,
    action: 'approve' | 'reject',
    note?: string,
  ): Promise<Deposit> {
    const dep = await this.depositRepo.findOne({ where: { id } });
    if (!dep) throw new NotFoundException('Deposit not found');
    if (dep.status !== 'pending') {
      throw new BadRequestException('Already processed');
    }
    if (action === 'approve') {
      await this.ensureWallet(dep.userId);
      await this.settle(dep.userId, Number(dep.amount), 'coins', null);
      dep.status = 'approved';
    } else {
      dep.status = 'rejected';
    }
    dep.note = note ?? null;
    dep.processedAt = new Date();
    return this.depositRepo.save(dep);
  }
}
