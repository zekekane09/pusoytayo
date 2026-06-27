import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('tournament')
@Controller('tournament')
export class TournamentStubController {
  @Get()
  getStatus() {
    return {
      status: 'coming_soon',
      message: 'Tournament system is under development',
    };
  }
}
