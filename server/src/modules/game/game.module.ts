import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Game, GamePlayer } from './entities/game.entity';
import { GameHistory } from './entities/game-history.entity';
import { AppSetting } from '../admin/app-setting.entity';
import { GameService } from './game.service';
import { GameLogicService } from './game-logic.service';
import { GameGateway } from './game.gateway';
import { WalletModule } from '../wallet/wallet.module';
import { RankingModule } from '../ranking/ranking.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Game, GamePlayer, GameHistory, AppSetting]),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get('JWT_SECRET', 'dev-secret'),
      }),
    }),
    WalletModule,
    RankingModule,
  ],
  providers: [GameService, GameLogicService, GameGateway],
  exports: [GameService, GameLogicService],
})
export class GameModule {}
