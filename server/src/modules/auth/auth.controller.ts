import { Controller, Post, Body, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly usersService: UsersService,
  ) {}

  @Post('login')
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('login-username')
  async loginUsername(@Body() body: { username: string; password: string }) {
    return this.authService.loginWithUsername(body.username, body.password);
  }

  @Post('register-username')
  async registerUsername(
    @Body()
    body: {
      username: string;
      password: string;
      displayName?: string;
      deviceId?: string;
    },
  ) {
    return this.authService.registerWithUsername(
      body.username,
      body.password,
      body.displayName,
      body.deviceId,
    );
  }

  @Post('refresh')
  async refresh(@Body() body: { refreshToken: string }) {
    return this.authService.refreshToken(body.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Get('profile')
  async getProfile(@Req() req: any) {
    return this.usersService.findById(req.user.id);
  }
}
