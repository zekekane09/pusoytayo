import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
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
