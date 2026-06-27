import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { GameService } from './game.service';

interface AuthenticatedSocket extends Socket {
  user?: { id: string; firebaseUid: string };
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/',
})
export class GameGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private playerSockets = new Map<string, string>();
  private roomTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly gameService: GameService,
    private readonly jwtService: JwtService,
  ) {}

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token = client.handshake.auth?.token;
      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token);
      client.user = { id: payload.sub, firebaseUid: payload.uid };
      this.playerSockets.set(payload.sub, client.id);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    if (client.user) {
      this.playerSockets.delete(client.user.id);
    }
  }

  @SubscribeMessage('lobby:list')
  async handleListRooms(@ConnectedSocket() client: AuthenticatedSocket) {
    const rooms = await this.gameService.getActiveRooms();
    const roomList = rooms.map((r) => ({
      code: r.roomCode,
      status: r.status,
      gameMode: r.gameMode,
      betAmount: r.betAmount,
      currency: r.currency,
      maxPlayers: r.maxPlayers,
      currentPlayers: r.players?.length || 0,
      createdAt: r.createdAt,
    }));

    client.emit('lobby:rooms_list', { rooms: roomList });
  }

  @SubscribeMessage('lobby:create')
  async handleCreateRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { gameMode?: string; betAmount?: number; currency?: string },
  ) {
    if (!client.user) return;

    try {
      const game = await this.gameService.createRoom(client.user.id, data);
      client.join(game.roomCode);

      client.emit('lobby:room_created', {
        code: game.roomCode,
        status: game.status,
        gameMode: game.gameMode,
        betAmount: game.betAmount,
        currency: game.currency,
      });

      this.broadcastRoomUpdate(game.roomCode);
    } catch (e: any) {
      client.emit('lobby:error', { message: e.message });
    }
  }

  @SubscribeMessage('lobby:join')
  async handleJoinRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { roomCode: string },
  ) {
    if (!client.user) return;

    try {
      const { game, seat } = await this.gameService.joinRoom(
        data.roomCode,
        client.user.id,
      );

      client.join(data.roomCode);
      client.emit('lobby:joined', { roomCode: data.roomCode, seat });

      this.server.to(data.roomCode).emit('lobby:room_updated', {
        code: game.roomCode,
        players: game.players.map((p) => ({
          id: p.userId,
          seat: p.seat,
          isReady: p.isReady,
        })),
        currentPlayers: game.players.length,
      });
    } catch (e: any) {
      client.emit('lobby:error', { message: e.message });
    }
  }

  @SubscribeMessage('lobby:leave')
  async handleLeaveRoom(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { roomCode: string },
  ) {
    if (!client.user) return;

    await this.gameService.leaveRoom(data.roomCode, client.user.id);
    client.leave(data.roomCode);
    client.emit('lobby:left', { roomCode: data.roomCode });

    this.broadcastRoomUpdate(data.roomCode);
  }

  @SubscribeMessage('game:ready')
  async handleReady(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { roomCode: string },
  ) {
    if (!client.user) return;

    try {
      const game = await this.gameService.setReady(
        data.roomCode,
        client.user.id,
        true,
      );

      this.server.to(data.roomCode).emit('lobby:room_updated', {
        players: game.players.map((p) => ({
          id: p.userId,
          seat: p.seat,
          isReady: p.isReady,
        })),
      });

      const allReady =
        game.players.length >= 2 && game.players.every((p) => p.isReady);

      if (allReady) {
        await this.startGameCountdown(data.roomCode);
      }
    } catch (e: any) {
      client.emit('game:error', { message: e.message });
    }
  }

  private async startGameCountdown(roomCode: string) {
    this.server.to(roomCode).emit('game:start', {
      countdown: 3,
      message: 'Game starting...',
    });

    setTimeout(async () => {
      try {
        const { game, hands } = await this.gameService.startGame(roomCode);

        for (const player of game.players) {
          const socketId = this.playerSockets.get(player.userId);
          if (socketId) {
            this.server.to(socketId).emit('game:deal', {
              cards: hands.get(player.userId),
            });
          }
        }

        this.server.to(roomCode).emit('game:arrange_phase', {
          timeLimit: 90,
        });

        this.startArrangeTimer(roomCode, 90);
      } catch (e: any) {
        this.server
          .to(roomCode)
          .emit('game:error', { message: e.message });
      }
    }, 3000);
  }

  private startArrangeTimer(roomCode: string, seconds: number) {
    let remaining = seconds;

    const timer = setInterval(() => {
      remaining--;
      this.server
        .to(roomCode)
        .emit('game:timer', { phase: 'arrange', secondsLeft: remaining });

      if (remaining <= 0) {
        clearInterval(timer);
        this.roomTimers.delete(roomCode);
        this.forceFinishArranging(roomCode);
      }
    }, 1000);

    this.roomTimers.set(roomCode, timer);
  }

  @SubscribeMessage('game:arrange')
  async handleArrange(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody()
    data: {
      roomCode: string;
      front: any[];
      middle: any[];
      back: any[];
    },
  ) {
    if (!client.user) return;

    try {
      const allDone = await this.gameService.submitArrangement(
        data.roomCode,
        client.user.id,
        data.front,
        data.middle,
        data.back,
      );

      this.server.to(data.roomCode).emit('game:arranged', {
        userId: client.user.id,
      });

      if (allDone) {
        const timer = this.roomTimers.get(data.roomCode);
        if (timer) {
          clearInterval(timer);
          this.roomTimers.delete(data.roomCode);
        }

        await this.revealAndScore(data.roomCode);
      }
    } catch (e: any) {
      client.emit('game:error', { message: e.message });
    }
  }

  private async forceFinishArranging(roomCode: string) {
    await this.revealAndScore(roomCode);
  }

  private async revealAndScore(roomCode: string) {
    try {
      const result = await this.gameService.finishGame(roomCode);

      this.server.to(roomCode).emit('game:finished', {
        scores: result.scores,
        winnerId: result.winnerId,
      });
    } catch (e: any) {
      this.server
        .to(roomCode)
        .emit('game:error', { message: e.message });
    }
  }

  private async broadcastRoomUpdate(roomCode: string) {
    const rooms = await this.gameService.getActiveRooms();
    this.server.emit('lobby:rooms_list', {
      rooms: rooms.map((r) => ({
        code: r.roomCode,
        status: r.status,
        currentPlayers: r.players?.length || 0,
        maxPlayers: r.maxPlayers,
        betAmount: r.betAmount,
        currency: r.currency,
        gameMode: r.gameMode,
      })),
    });
  }
}
