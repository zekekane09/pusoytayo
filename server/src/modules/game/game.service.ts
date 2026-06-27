import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Game, GamePlayer } from './entities/game.entity';
import { GameLogicService, Card } from './game-logic.service';
import { WalletService } from '../wallet/wallet.service';
import { RankingService } from '../ranking/ranking.service';

@Injectable()
export class GameService {
  constructor(
    @InjectRepository(Game)
    private readonly gameRepo: Repository<Game>,
    @InjectRepository(GamePlayer)
    private readonly gpRepo: Repository<GamePlayer>,
    private readonly gameLogic: GameLogicService,
    private readonly walletService: WalletService,
    private readonly rankingService: RankingService,
  ) {}

  generateRoomCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
  }

  async createRoom(userId: string, options: {
    gameMode?: string;
    betAmount?: number;
    currency?: string;
    maxPlayers?: number;
  }): Promise<Game> {
    const roomCode = this.generateRoomCode();

    const game = this.gameRepo.create({
      roomCode,
      gameMode: options.gameMode || 'classic',
      betAmount: options.betAmount || 0,
      currency: options.currency || 'coins',
      maxPlayers: options.maxPlayers || 4,
      createdBy: userId,
      status: 'waiting',
    });

    const saved = await this.gameRepo.save(game);

    await this.gpRepo.save(
      this.gpRepo.create({
        gameId: saved.id,
        userId,
        seat: 0,
      }),
    );

    return (await this.gameRepo.findOne({
      where: { id: saved.id },
      relations: ['players'],
    }))!;
  }

  async joinRoom(
    roomCode: string,
    userId: string,
  ): Promise<{ game: Game; seat: number }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) throw new BadRequestException('Room not found');
    if (game.status !== 'waiting')
      throw new BadRequestException('Game already started');

    const existing = game.players.find((p) => p.userId === userId);
    if (existing) return { game, seat: existing.seat };

    if (game.players.length >= game.maxPlayers)
      throw new BadRequestException('Room is full');

    const takenSeats = new Set(game.players.map((p) => p.seat));
    let seat = 0;
    while (takenSeats.has(seat)) seat++;

    await this.gpRepo.save(
      this.gpRepo.create({ gameId: game.id, userId, seat }),
    );

    const updated = await this.gameRepo.findOne({
      where: { id: game.id },
      relations: ['players'],
    });

    return { game: updated!, seat };
  }

  async leaveRoom(roomCode: string, userId: string): Promise<void> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) return;

    await this.gpRepo.delete({ gameId: game.id, userId });

    const remaining = await this.gpRepo.count({
      where: { gameId: game.id },
    });

    if (remaining === 0) {
      game.status = 'cancelled';
      await this.gameRepo.save(game);
    }
  }

  async setReady(
    roomCode: string,
    userId: string,
    ready: boolean,
  ): Promise<Game> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) throw new BadRequestException('Room not found');

    const player = game.players.find((p) => p.userId === userId);
    if (!player) throw new BadRequestException('Not in this room');

    player.isReady = ready;
    await this.gpRepo.save(player);

    return (await this.gameRepo.findOne({
      where: { id: game.id },
      relations: ['players'],
    }))!;
  }

  async startGame(roomCode: string): Promise<{
    game: Game;
    hands: Map<string, Card[]>;
  }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) throw new BadRequestException('Room not found');
    if (game.players.length < 2)
      throw new BadRequestException('Need at least 2 players');

    const allReady = game.players.every((p) => p.isReady);
    if (!allReady) throw new BadRequestException('Not all players ready');

    if (game.betAmount > 0) {
      for (const player of game.players) {
        await this.walletService.deductBet(
          player.userId,
          game.betAmount,
          game.currency as 'coins' | 'cash',
          game.id,
        );
      }
    }

    const dealtHands = this.gameLogic.dealCards(game.players.length);
    const hands = new Map<string, Card[]>();

    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      player.cardsJson = dealtHands[i];
      hands.set(player.userId, dealtHands[i]);
      await this.gpRepo.save(player);
    }

    game.status = 'arranging';
    game.startedAt = new Date();
    await this.gameRepo.save(game);

    return { game, hands };
  }

  async submitArrangement(
    roomCode: string,
    userId: string,
    front: Card[],
    middle: Card[],
    back: Card[],
  ): Promise<boolean> {
    if (!this.gameLogic.validateArrangement(front, middle, back)) {
      throw new BadRequestException(
        'Invalid arrangement: back must beat middle, middle must beat front',
      );
    }

    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) throw new BadRequestException('Room not found');

    const player = game.players.find((p) => p.userId === userId);
    if (!player) throw new BadRequestException('Not in this room');

    player.frontHand = front;
    player.middleHand = middle;
    player.backHand = back;
    await this.gpRepo.save(player);

    const allArranged = game.players.every(
      (p) => p.userId === userId || p.frontHand !== null,
    );

    return allArranged;
  }

  async finishGame(roomCode: string): Promise<{
    scores: Record<string, number>;
    winnerId: string;
  }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });

    if (!game) throw new BadRequestException('Room not found');

    const arrangements = game.players.map((p) => ({
      playerId: p.userId,
      front: p.frontHand as Card[],
      middle: p.middleHand as Card[],
      back: p.backHand as Card[],
    }));

    const scores = this.gameLogic.calculateScores(arrangements);

    let winnerId = '';
    let highScore = -Infinity;
    for (const [id, score] of Object.entries(scores)) {
      if (score > highScore) {
        highScore = score;
        winnerId = id;
      }
    }

    for (const player of game.players) {
      player.score = scores[player.userId] || 0;
      await this.gpRepo.save(player);
    }

    game.status = 'finished';
    game.winnerId = winnerId;
    game.finishedAt = new Date();
    await this.gameRepo.save(game);

    if (game.betAmount > 0) {
      const pot = game.betAmount * game.players.length;
      await this.walletService.creditWinnings(
        winnerId,
        pot,
        game.currency as 'coins' | 'cash',
        game.id,
      );
    }

    for (const player of game.players) {
      const won = player.userId === winnerId;
      await this.rankingService.updateRanking(player.userId, won);
    }

    return { scores, winnerId };
  }

  async getActiveRooms(): Promise<Game[]> {
    return this.gameRepo.find({
      where: { status: 'waiting' },
      relations: ['players'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }
}
