import { Controller, Get, UseGuards, Req, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RankingService } from './ranking.service';

@ApiTags('rankings')
@Controller('rankings')
export class RankingController {
  constructor(private readonly rankingService: RankingService) {}

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get()
  async getMyRanking(@Req() req: any) {
    return this.rankingService.getRanking(req.user.id);
  }

  @Get('leaderboard')
  async getLeaderboard(@Query('limit') limit?: number) {
    return this.rankingService.getLeaderboard(limit || 100);
  }

  /** Leaderboard ranked by the biggest single-deal win. */
  @Get('top-wins')
  async getTopWins(@Query('limit') limit?: number) {
    const rows = await this.rankingService.getTopWins(limit || 100);
    return rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      name: r.user?.displayName ?? 'Player',
      tier: r.rankTier,
      highestWin: Number(r.highestWin),
      totalWagered: Number(r.totalWagered),
      wins: r.wins,
    }));
  }
}
