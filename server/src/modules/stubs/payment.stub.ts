import { Controller, Post, Body, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('payment')
@Controller('payment')
export class PaymentStubController {
  @Post('gcash/deposit')
  async requestDeposit(
    @Body()
    body: {
      amount: number;
      gcashReferenceNumber: string;
      receiptUrl?: string;
    },
  ) {
    return {
      status: 'pending',
      message: 'Deposit request submitted for admin approval',
      requestId: `DEP-${Date.now()}`,
      amount: body.amount,
    };
  }

  @Post('gcash/withdraw')
  async requestWithdrawal(
    @Body()
    body: {
      amount: number;
      gcashNumber: string;
    },
  ) {
    return {
      status: 'pending',
      message: 'Withdrawal request submitted for admin approval',
      requestId: `WTH-${Date.now()}`,
      amount: body.amount,
    };
  }

  @Get('status')
  getPaymentStatus() {
    return {
      gcash: { enabled: true, minDeposit: 50, maxDeposit: 50000 },
      qrph: { enabled: false, message: 'Coming soon' },
    };
  }
}
