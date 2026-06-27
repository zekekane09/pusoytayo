import { Controller, Get, Patch, Body, UseGuards, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('profile')
  async getProfile(@Req() req: any) {
    return this.usersService.findById(req.user.id);
  }

  @Patch('profile')
  async updateProfile(
    @Req() req: any,
    @Body() body: { displayName?: string; avatarUrl?: string },
  ) {
    return this.usersService.updateProfile(req.user.id, body);
  }
}
