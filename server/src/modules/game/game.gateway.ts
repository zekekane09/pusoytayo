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
  // Guards against scoring a room twice (e.g. the last submit and the arrange
  // timer firing at the same moment) which would double-settle wallets.
  private revealing = new Set<string>();

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

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.user) {
      this.playerSockets.delete(client.user.id);
      // Free up any waiting room they were sitting in so it doesn't linger as a
      // ghost in the lobby.
      await this.gameService
        .removeFromWaitingRooms(client.user.id)
        .catch(() => undefined);
    }
  }

  // The "host"/banker is the lowest-seated remaining player, so if the original
  // creator leaves, the next earliest joiner takes over.
  private hostName(game: any): string {
    const first = [...(game.players || [])].sort((a, b) => a.seat - b.seat)[0];
    return first?.user?.displayName ?? 'Host';
  }

  @SubscribeMessage('lobby:list')
  async handleListRooms(@ConnectedSocket() client: AuthenticatedSocket) {
    // Drop ghost rooms whose players are all disconnected before listing.
    await this.gameService
      .cancelStaleRooms([...this.playerSockets.keys()])
      .catch(() => undefined);
    const rooms = await this.gameService.getActiveRooms();
    const roomList = rooms.map((r) => ({
      code: r.roomCode,
      status: r.status,
      gameMode: r.gameMode,
      betAmount: r.betAmount,
      currency: r.currency,
      maxPlayers: r.maxPlayers,
      currentPlayers: r.players?.length || 0,
      hostName: this.hostName(r),
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

      this.server
        .to(data.roomCode)
        .emit('lobby:room_updated', this.roomUpdatePayload(game));
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
      // If they've reviewed the result and are out of coins, remove them now
      // instead of starting another round.
      const broke = await this.gameService.kickIfBroke(
        data.roomCode,
        client.user.id,
      );
      if (broke) {
        const sid = this.playerSockets.get(client.user.id);
        if (sid) {
          this.server.to(sid).emit('game:kicked', { reason: 'Out of coins' });
        }
        // Update the players still in the room (the kicked one is gone).
        const fresh = await this.gameService.getRoomState(data.roomCode);
        if (fresh) {
          this.server
            .to(data.roomCode)
            .emit('lobby:room_updated', this.roomUpdatePayload(fresh));
        }
        await this.broadcastRoomUpdate(data.roomCode);
        return;
      }

      const game = await this.gameService.setReady(
        data.roomCode,
        client.user.id,
        true,
      );

      this.server
        .to(data.roomCode)
        .emit('lobby:room_updated', this.roomUpdatePayload(game));

      const allReady =
        game.players.length >= 2 && game.players.every((p) => p.isReady);

      if (allReady) {
        await this.startBettingPhase(data.roomCode);
      }
    } catch (e: any) {
      client.emit('game:error', { message: e.message });
    }
  }

  /**
   * Betting phase: broadcast the limits, open a 20s window for players to lock
   * their bets, then deal once everyone has bet or the timer expires.
   */
  private async startBettingPhase(roomCode: string) {
    const config = await this.gameService.bettingConfig(roomCode);
    await this.gameService.enterBetting(roomCode);

    this.server.to(roomCode).emit('game:betting_phase', {
      min: config.min,
      max: config.max,
      timeLimit: config.timeLimit,
      mode: config.mode,
      bankerBankroll: config.bankerBankroll,
    });

    let remaining = config.timeLimit;
    const timer = setInterval(async () => {
      remaining--;
      this.server
        .to(roomCode)
        .emit('game:timer', { phase: 'betting', secondsLeft: remaining });
      if (remaining <= 0) {
        clearInterval(timer);
        this.roomTimers.delete(roomCode);
        await this.gameService.lockBets(roomCode);
        await this.startGameCountdown(roomCode);
      }
    }, 1000);
    this.roomTimers.set(roomCode, timer);
  }

  @SubscribeMessage('game:place_bet')
  async handlePlaceBet(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { roomCode: string; amount: number },
  ) {
    if (!client.user) return;
    try {
      const { game, allBet } = await this.gameService.placeBet(
        data.roomCode,
        client.user.id,
        data.amount,
      );

      this.server.to(data.roomCode).emit('game:bet_placed', {
        bets: game.players.map((p) => ({
          id: p.userId,
          seat: p.seat,
          bet: Number(p.bet),
          hasBet: p.hasBet,
        })),
      });

      if (allBet) {
        const timer = this.roomTimers.get(data.roomCode);
        if (timer) {
          clearInterval(timer);
          this.roomTimers.delete(data.roomCode);
        }
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

  @SubscribeMessage('game:unarrange')
  async handleUnarrange(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { roomCode: string },
  ) {
    if (!client.user) return;
    const ok = await this.gameService.cancelArrangement(
      data.roomCode,
      client.user.id,
    );
    if (ok) {
      this.server
          .to(data.roomCode)
          .emit('game:unarranged', { userId: client.user.id });
    }
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
    if (this.revealing.has(roomCode)) return;
    this.revealing.add(roomCode);
    try {
      const result = await this.gameService.finishGame(roomCode);

      // Full server-authoritative reveal: every player's arranged hands, the
      // per-row winners (so the client can reveal top -> middle -> bottom), the
      // mode, banker, pot, and final scores.
      this.server.to(roomCode).emit('game:finished', {
        mode: result.mode,
        bankerId: result.bankerId,
        pot: result.pot,
        rowWinners: result.rowWinners,
        scores: result.scores,
        winnerId: result.winnerId,
        players: result.players,
      });
      // Note: broke players are NOT kicked here — they stay to review the
      // result, and are removed only when they tap "Next" (see handleReady).
    } catch (e: any) {
      this.server
        .to(roomCode)
        .emit('game:error', { message: e.message });
    } finally {
      this.revealing.delete(roomCode);
    }
  }

  /** Shared room snapshot for lobby:room_updated, incl. mode + banker. */
  private roomUpdatePayload(game: any) {
    const banker =
      game.gameMode === 'banker'
        ? [...game.players].sort((a, b) => a.seat - b.seat)[0]
        : null;
    return {
      code: game.roomCode,
      gameMode: game.gameMode,
      betAmount: Number(game.betAmount),
      bankerId: banker?.userId ?? null,
      players: game.players.map((p: any) => ({
        id: p.userId,
        seat: p.seat,
        isReady: p.isReady,
        name: p.user?.displayName ?? `Seat ${p.seat + 1}`,
      })),
      currentPlayers: game.players.length,
    };
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
        hostName: this.hostName(r),
      })),
    });
  }
}
