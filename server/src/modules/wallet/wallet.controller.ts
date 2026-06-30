import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';

@ApiTags('wallet')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  async getWallet(@Req() req: any) {
    const w = await this.walletService.getWallet(req.user.id);
    const coins = Number(w.coins);
    const locked = Number(w.bonusLocked || 0);
    return {
      ...w,
      coins,
      cash: Number(w.cash),
      bonusLocked: locked,
      withdrawable: Math.max(0, coins - locked),
    };
  }

  @Post('withdraw')
  async withdraw(
    @Req() req: any,
    @Body()
    body: {
      amount: number;
      gcashNumber: string;
      gcashName: string;
      displayName?: string;
    },
  ) {
    return this.walletService.requestWithdrawal(
      req.user.id,
      body.displayName || 'Player',
      body.amount,
      body.gcashNumber,
      body.gcashName,
    );
  }

  @Get('withdrawals')
  async myWithdrawals(@Req() req: any) {
    return { withdrawals: await this.walletService.userWithdrawals(req.user.id) };
  }

  @Post('deposit')
  async deposit(
    @Req() req: any,
    @Body()
    body: { amount: number; gcashRef: string; displayName?: string },
  ) {
    return this.walletService.requestDeposit(
      req.user.id,
      body.displayName || 'Player',
      body.amount,
      body.gcashRef,
    );
  }

  @Get('deposits')
  async myDeposits(@Req() req: any) {
    return { deposits: await this.walletService.userDeposits(req.user.id) };
  }

  @Get('transactions')
  async getTransactions(
    @Req() req: any,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.walletService.getTransactions(
      req.user.id,
      limit || 50,
      offset || 0,
    );
  }
}
