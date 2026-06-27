import { Module, Controller, Get } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { GameModule } from './modules/game/game.module';
import { LobbyModule } from './modules/lobby/lobby.module';
import { RankingModule } from './modules/ranking/ranking.module';

@Controller('health')
class HealthController {
  @Get()
  check() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        // Cloud hosts (Render/Railway/etc.) provide a single DATABASE_URL and
        // require SSL; locally we fall back to the individual DB_* vars.
        const url = config.get<string>('DATABASE_URL');
        const synchronize = config.get('DB_SYNCHRONIZE', 'true') === 'true';
        const logging = config.get('NODE_ENV') === 'development';
        if (url) {
          return {
            type: 'postgres' as const,
            url,
            ssl: { rejectUnauthorized: false },
            autoLoadEntities: true,
            synchronize,
            logging,
          };
        }
        return {
          type: 'postgres' as const,
          host: config.get<string>('DB_HOST', 'localhost'),
          port: config.get<number>('DB_PORT', 5432),
          username: config.get<string>('DB_USERNAME', 'pusoy'),
          password: config.get<string>('DB_PASSWORD', 'pusoy_password'),
          database: config.get<string>('DB_DATABASE', 'pusoy_tayo'),
          autoLoadEntities: true,
          synchronize,
          logging,
        };
      },
    }),
    AuthModule,
    UsersModule,
    WalletModule,
    GameModule,
    LobbyModule,
    RankingModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
