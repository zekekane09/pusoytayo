import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';

@Injectable()
export class WsAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const client: Socket = context.switchToWs().getClient();
    const token = client.handshake.auth?.token;

    if (!token) {
      throw new WsException('Authentication token missing');
    }

    try {
      const payload = this.jwtService.verify(token);
      (client as any).user = { id: payload.sub, firebaseUid: payload.uid };
      return true;
    } catch {
      throw new WsException('Invalid authentication token');
    }
  }
}
