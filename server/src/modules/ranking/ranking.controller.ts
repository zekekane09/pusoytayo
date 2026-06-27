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
}
