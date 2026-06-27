import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlayerRanking } from './entities/player-ranking.entity';
import { RankingService } from './ranking.service';
import { RankingController } from './ranking.controller';

@Module({
  imports: [TypeOrmModule.forFeature([PlayerRanking])],
  providers: [RankingService],
  controllers: [RankingController],
  exports: [RankingService],
})
export class RankingModule {}
