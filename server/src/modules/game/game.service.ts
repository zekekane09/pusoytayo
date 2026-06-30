import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Not, In } from 'typeorm';
import { Game, GamePlayer } from './entities/game.entity';
import { GameHistory } from './entities/game-history.entity';
import { AppSetting } from '../admin/app-setting.entity';
import { GameLogicService, Card } from './game-logic.service';
import { WalletService } from '../wallet/wallet.service';
import { RankingService } from '../ranking/ranking.service';

@Injectable()
export class GameService {
  /** Flat house fee taken from the round winner's winnings (per deal). */
  private static readonly RAKE = 5;

  constructor(
    @InjectRepository(Game)
    private readonly gameRepo: Repository<Game>,
    @InjectRepository(GamePlayer)
    private readonly gpRepo: Repository<GamePlayer>,
    @InjectRepository(GameHistory)
    private readonly historyRepo: Repository<GameHistory>,
    @InjectRepository(AppSetting)
    private readonly settingRepo: Repository<AppSetting>,
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
    const gameMode = options.gameMode || 'classic';
    const betAmount = options.betAmount || 0;
    const maxPlayers = options.maxPlayers || 4;
    const currency = (options.currency || 'coins') as 'coins' | 'cash';

    // Mode must be enabled by the admin.
    const modes = await this.enabledModes();
    if (modes[gameMode] === false) {
      throw new BadRequestException('This game mode is currently disabled');
    }

    // Banker must be able to cover the worst case — every opponent beating them.
    // Each player risks only their bet, so liability = (maxPlayers-1) x bet.
    if (gameMode === 'banker' && betAmount > 0) {
      const wallet = await this.walletService.getWallet(userId).catch(() => null);
      const balance = wallet
        ? Number(currency === 'cash' ? wallet.cash : wallet.coins)
        : 0;
      const liability = (maxPlayers - 1) * betAmount;
      if (balance < liability) {
        throw new BadRequestException(
          `Insufficient balance to act as Banker. Need ${liability} ${currency}.`,
        );
      }
    }

    const roomCode = this.generateRoomCode();

    const game = this.gameRepo.create({
      roomCode,
      gameMode,
      betAmount,
      currency,
      maxPlayers,
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
      relations: ['players', 'players.user'],
    }))!;
  }

  async joinRoom(
    roomCode: string,
    userId: string,
  ): Promise<{ game: Game; seat: number }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });

    if (!game) throw new BadRequestException('Room not found');
    if (game.status === 'finished' || game.status === 'cancelled') {
      throw new BadRequestException('Game already ended');
    }
    // Joining mid-game is allowed — the new player simply sits out the current
    // round and is dealt in on the next deal.

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
      relations: ['players', 'players.user'],
    });

    return { game: updated!, seat };
  }

  async leaveRoom(roomCode: string, userId: string): Promise<void> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
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
      relations: ['players', 'players.user'],
    });

    if (!game) throw new BadRequestException('Room not found');

    const player = game.players.find((p) => p.userId === userId);
    if (!player) throw new BadRequestException('Not in this room');

    player.isReady = ready;
    await this.gpRepo.save(player);

    return (await this.gameRepo.findOne({
      where: { id: game.id },
      relations: ['players', 'players.user'],
    }))!;
  }

  /**
   * Betting limits for a room. The minimum is the room's configured bet; the
   * maximum is capped so a banker's bankroll can always cover a worst-case
   * payout (every other player scooping 6x their bet).
   */
  async bettingConfig(roomCode: string): Promise<{
    min: number;
    max: number;
    timeLimit: number;
    mode: string;
    bankerBankroll: number;
  }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });
    if (!game) throw new BadRequestException('Room not found');

    const min = Number(game.betAmount) || 0;
    // Players may wager up to their own balance — the actual cap is applied
    // per-player in placeBet against their wallet (and the banker's bankroll).
    const max = 100000000;

    // In banker mode players collectively can't bet more than the banker holds.
    let bankerBankroll = 0;
    if (game.gameMode === 'banker' && game.players.length > 0) {
      const banker = [...game.players].sort((a, b) => a.seat - b.seat)[0];
      const w = await this.walletService.getWallet(banker.userId).catch(() => null);
      bankerBankroll = w
        ? Number(game.currency === 'cash' ? w.cash : w.coins)
        : 0;
    }
    return { min, max, timeLimit: 20, mode: game.gameMode, bankerBankroll };
  }

  /** Enter the betting phase: reset bets and mark the room as betting. */
  async enterBetting(roomCode: string): Promise<Game> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });
    if (!game) throw new BadRequestException('Room not found');

    game.status = 'betting';
    await this.gameRepo.save(game);
    // In banker mode the banker (seat 0) does not place a bet — only the
    // players wager against them — so auto-complete the banker's bet.
    const bankerId =
      game.gameMode === 'banker'
        ? [...game.players].sort((a, b) => a.seat - b.seat)[0]?.userId
        : null;
    for (const p of game.players) {
      const isBanker = p.userId === bankerId;
      p.bet = isBanker ? 0 : Number(game.betAmount) || 0;
      p.hasBet = isBanker; // banker is already "done"
      await this.gpRepo.save(p);
    }
    return (await this.gameRepo.findOne({
      where: { id: game.id },
      relations: ['players', 'players.user'],
    }))!;
  }

  /** Record a player's chosen bet (clamped to the room's betting limits). */
  async placeBet(
    roomCode: string,
    userId: string,
    amount: number,
  ): Promise<{ game: Game; allBet: boolean }> {
    const { min, max } = await this.bettingConfig(roomCode);
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });
    if (!game) throw new BadRequestException('Room not found');

    const player = game.players.find((p) => p.userId === userId);
    if (!player) throw new BadRequestException('Not in this room');

    // A player can wager up to all their coins; never below the room minimum.
    const cur = game.currency as 'coins' | 'cash';
    const wallet = await this.walletService.getWallet(userId).catch(() => null);
    const balance = wallet
      ? Number(cur === 'cash' ? wallet.cash : wallet.coins)
      : max;
    let desired = Math.min(Math.max(min, balance), Math.max(min, Math.floor(amount)));

    // Banker mode: the banker only covers up to their balance, first-come
    // first-served. Cap this bet to the banker's remaining bankroll after the
    // bets already locked by other players. If nothing is left, the bet is 0.
    if (game.gameMode === 'banker') {
      const banker = [...game.players].sort((a, b) => a.seat - b.seat)[0];
      const bankerWallet = await this.walletService
        .getWallet(banker.userId)
        .catch(() => null);
      const bankroll = bankerWallet
        ? Number(cur === 'cash' ? bankerWallet.cash : bankerWallet.coins)
        : 0;
      const lockedByOthers = game.players
        .filter(
          (p) =>
            p.userId !== banker.userId &&
            p.userId !== userId &&
            p.hasBet,
        )
        .reduce((s, p) => s + (Number(p.bet) || 0), 0);
      const remaining = Math.max(0, bankroll - lockedByOthers);
      desired = Math.min(desired, remaining); // may be 0 if fully subscribed
    }

    player.bet = desired;
    player.hasBet = true;
    await this.gpRepo.save(player);

    const fresh = (await this.gameRepo.findOne({
      where: { id: game.id },
      relations: ['players', 'players.user'],
    }))!;
    return { game: fresh, allBet: fresh.players.every((p) => p.hasBet) };
  }

  /** Fill in the minimum bet for anyone who didn't choose before the timer. */
  async lockBets(roomCode: string): Promise<void> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });
    if (!game) return;
    for (const p of game.players) {
      if (!p.hasBet) {
        p.bet = Number(game.betAmount) || 0;
        p.hasBet = true;
        await this.gpRepo.save(p);
      }
    }
  }

  async startGame(
    roomCode: string,
    participantIds?: string[],
  ): Promise<{
    game: Game;
    hands: Map<string, Card[]>;
  }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });

    if (!game) throw new BadRequestException('Room not found');

    // Only the players who were in the room when the round committed take part.
    // Anyone who joined during the betting/countdown window sits out this deal
    // and is dealt in on the next one.
    const set = participantIds ? new Set(participantIds) : null;
    const participants = set
      ? game.players.filter((p) => set.has(p.userId))
      : game.players;
    // Players sitting this round out (late joiners): clear any stale cards so
    // they're excluded from scoring/reveal.
    for (const p of game.players) {
      if (set && !set.has(p.userId)) {
        p.cardsJson = null;
        p.frontHand = null;
        p.middleHand = null;
        p.backHand = null;
        await this.gpRepo.save(p);
      }
    }

    if (participants.length < 2)
      throw new BadRequestException('Need at least 2 players');

    const allReady = participants.every((p) => p.isReady);
    if (!allReady) throw new BadRequestException('Not all players ready');

    // Each player stakes the bet they locked in during the betting phase.
    // Banker mode is the exception: nothing is anted up front — chips are
    // settled head-to-head against the banker at the end of the round.
    if (game.gameMode !== 'banker') {
      for (const player of participants) {
        const stake = Number(player.bet) || 0;
        if (stake > 0) {
          await this.walletService.deductBet(
            player.userId,
            stake,
            game.currency as 'coins' | 'cash',
            game.id,
          );
        }
      }
    }

    const dealtHands = this.gameLogic.dealCards(participants.length);
    const hands = new Map<string, Card[]>();

    for (let i = 0; i < participants.length; i++) {
      const player = participants[i];
      player.cardsJson = dealtHands[i];
      // Clear last round's arrangement so the "who has arranged" check is fresh.
      player.frontHand = null;
      player.middleHand = null;
      player.backHand = null;
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
      relations: ['players', 'players.user'],
    });

    if (!game) throw new BadRequestException('Room not found');

    const player = game.players.find((p) => p.userId === userId);
    if (!player) throw new BadRequestException('Not in this room');

    // Anti-cheat / consistency: the submitted 13 cards must be exactly the hand
    // that was dealt to this player.
    const dealt = (player.cardsJson as Card[]) || [];
    const key = (cs: Card[]) =>
      cs.map((c) => `${c.rank}${c.suit}`).sort().join(',');
    if (key([...front, ...middle, ...back]) !== key(dealt)) {
      throw new BadRequestException('Submitted cards do not match your hand');
    }

    player.frontHand = front;
    player.middleHand = middle;
    player.backHand = back;
    await this.gpRepo.save(player);

    // Re-read committed state: two players submitting at once would each see a
    // stale snapshot of the other, so count freshly who still hasn't arranged.
    // Only players who were dealt this round (cardsJson set) are awaited; late
    // joiners sitting out have null hands and must not block the round.
    const pending = await this.gpRepo.count({
      where: {
        gameId: game.id,
        frontHand: IsNull(),
        cardsJson: Not(IsNull()),
      },
    });
    return pending === 0;
  }

  /**
   * Remove a player (or banker) from a staked room if they're out of coins.
   * Called when they try to continue to the next round (after reviewing the
   * result). Returns true if they were removed.
   */
  async kickIfBroke(roomCode: string, userId: string): Promise<boolean> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });
    if (!game || Number(game.betAmount) <= 0) return false;
    const cur = game.currency as 'coins' | 'cash';
    const w = await this.walletService.getWallet(userId).catch(() => null);
    const bal = w ? Number(cur === 'cash' ? w.cash : w.coins) : 0;
    if (bal > 0) return false;
    await this.gpRepo.delete({ gameId: game.id, userId });
    const remaining = await this.gpRepo.count({ where: { gameId: game.id } });
    if (remaining === 0) {
      game.status = 'cancelled';
      await this.gameRepo.save(game);
    }
    return true;
  }

  /**
   * Cancel a player's submitted arrangement so they can edit again — only while
   * the round is still in the arranging phase (before the reveal).
   */
  async cancelArrangement(roomCode: string, userId: string): Promise<boolean> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players'],
    });
    if (!game || game.status !== 'arranging') return false;
    const player = game.players.find((p) => p.userId === userId);
    if (!player) return false;
    player.frontHand = null;
    player.middleHand = null;
    player.backHand = null;
    await this.gpRepo.save(player);
    return true;
  }

  async finishGame(roomCode: string): Promise<{
    mode: string;
    bankerId: string | null;
    scores: Record<string, number>;
    winnerId: string;
    pot: number;
    rake: number;
    rowWinners: { front: string | null; middle: string | null; back: string | null };
    players: {
      userId: string;
      seat: number;
      score: number;
      coins: number;
      bet: number;
      front: Card[];
      middle: Card[];
      back: Card[];
      frontType: number;
      middleType: number;
      backType: number;
      locked: boolean;
      displayName: string;
    }[];
  }> {
    const game = await this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });

    if (!game) throw new BadRequestException('Room not found');

    // Only players who were dealt this round are scored; anyone who joined
    // mid-round (no cards) sits out and plays from the next deal.
    const dealt = game.players.filter(
      (p) => Array.isArray(p.cardsJson) && (p.cardsJson as Card[]).length === 13,
    );

    // Anyone who didn't submit before the timer gets an auto-arranged hand, so
    // the reveal always works once everyone is ready OR the timer ends.
    for (const p of dealt) {
      if (!p.frontHand || !p.middleHand || !p.backHand) {
        const a = this.gameLogic.autoArrange((p.cardsJson as Card[]) || []);
        p.frontHand = a.front;
        p.middleHand = a.middle;
        p.backHand = a.back;
        await this.gpRepo.save(p);
      }
    }

    const arrangements = dealt.map((p) => ({
      playerId: p.userId,
      front: p.frontHand as Card[],
      middle: p.middleHand as Card[],
      back: p.backHand as Card[],
    }));

    // The banker is the lowest-seated dealt player in banker mode.
    const mode = game.gameMode;
    const bankerId =
      mode === 'banker'
        ? [...dealt].sort((a, b) => a.seat - b.seat)[0]?.userId ?? null
        : null;

    // Authoritative scoring per mode.
    let scores: Record<string, number>;
    let pot = 0;
    let rowWinners: { front: string | null; middle: string | null; back: string | null } = {
      front: null,
      middle: null,
      back: null,
    };

    if (mode === 'banker' && bankerId) {
      scores = this.gameLogic.calculateBankerScores(arrangements, bankerId);
    } else if (mode === 'pot') {
      const antes: Record<string, number> = {};
      for (const p of game.players) antes[p.userId] = Number(p.bet) || 0;
      const dist = this.gameLogic.calculatePotDistribution(arrangements, antes);
      // In pot mode the "score" is the net chip change so the reveal and the
      // wallet stay in agreement.
      scores = dist.net;
      pot = dist.pot;
      rowWinners = dist.rowWinners;
    } else {
      scores = this.gameLogic.calculateScores(arrangements);
    }

    let winnerId = '';
    let highScore = -Infinity;
    for (const [id, score] of Object.entries(scores)) {
      if (score > highScore) {
        highScore = score;
        winnerId = id;
      }
    }

    for (const player of dealt) {
      player.score = scores[player.userId] || 0;
      await this.gpRepo.save(player);
    }

    // Clear everyone's ready flag so the NEXT round can't start until every
    // player taps "Next" to re-confirm — no stale readiness from this round.
    for (const player of game.players) {
      if (player.isReady) {
        player.isReady = false;
        await this.gpRepo.save(player);
      }
    }

    game.status = 'finished';
    game.winnerId = winnerId;
    game.finishedAt = new Date();
    await this.gameRepo.save(game);

    // Wallet settlement (only when real stakes are in play).
    const anyStake = dealt.some((p) => Number(p.bet) > 0);
    if (anyStake) {
      const currency = game.currency as 'coins' | 'cash';
      if (mode === 'banker' && bankerId) {
        // Each player settles head-to-head vs the banker: chips = points x the
        // player's own bet. The banker's net is the mirror of what was actually
        // applied (debits are clamped to balance, so use the applied amounts to
        // keep the books balanced).
        let bankerDelta = 0;
        for (const p of dealt) {
          if (p.userId === bankerId) continue;
          // The player risks only their bet: win it or lose it based on who
          // wins more rows (no point multiplier).
          const pts = scores[p.userId] || 0;
          const bet = Number(p.bet) || 0;
          const chip = pts > 0 ? bet : pts < 0 ? -bet : 0;
          const applied = await this.walletService.settle(
            p.userId,
            chip,
            currency,
            game.id,
          );
          bankerDelta -= applied;
        }
        await this.walletService.settle(
          bankerId,
          bankerDelta,
          currency,
          game.id,
        );
      } else if (mode === 'pot') {
        // Each player already had their own bet deducted at deal; credit back
        // their net share (net + own ante is always >= 0 in pot mode).
        for (const player of dealt) {
          const credit = (scores[player.userId] || 0) + (Number(player.bet) || 0);
          if (credit > 0) {
            await this.walletService.creditWinnings(
              player.userId,
              credit,
              currency,
              game.id,
            );
          }
        }
      } else if (mode !== 'banker') {
        // Classic: winner takes the whole pot (sum of every player's stake).
        const pot = dealt.reduce(
          (sum, p) => sum + (Number(p.bet) || 0),
          0,
        );
        await this.walletService.creditWinnings(
          winnerId,
          pot,
          currency,
          game.id,
        );
      }
    }

    for (const player of dealt) {
      const won = player.userId === winnerId;
      await this.rankingService.updateRanking(player.userId, won);
    }

    // Actual money (coins) won/lost per player, matching the wallet settlement,
    // so the reveal shows real winnings rather than raw points.
    const coinByUser: Record<string, number> = {};
    for (const p of dealt) coinByUser[p.userId] = 0;
    if (anyStake) {
      if (mode === 'banker' && bankerId) {
        let bankerDelta = 0;
        for (const p of dealt) {
          if (p.userId === bankerId) continue;
          const pts = scores[p.userId] || 0;
          const bet = Number(p.bet) || 0;
          const chip = pts > 0 ? bet : pts < 0 ? -bet : 0;
          coinByUser[p.userId] = chip;
          bankerDelta -= chip;
        }
        coinByUser[bankerId] = bankerDelta;
      } else if (mode === 'pot') {
        for (const p of dealt) coinByUser[p.userId] = scores[p.userId] || 0;
      } else {
        const totalPot = dealt.reduce(
          (s, p) => s + (Number(p.bet) || 0),
          0,
        );
        for (const p of dealt) {
          coinByUser[p.userId] =
            (p.userId === winnerId ? totalPot : 0) - (Number(p.bet) || 0);
        }
      }
    }

    // House rake: take a flat 5-coin fee from the winner's winnings each deal.
    let rake = 0;
    if (anyStake && winnerId && (coinByUser[winnerId] || 0) > 0) {
      const currency = game.currency as 'coins' | 'cash';
      const fee = Math.min(GameService.RAKE, coinByUser[winnerId]);
      const applied = await this.walletService.settle(
        winnerId,
        -fee,
        currency,
        game.id,
      );
      rake = -applied; // applied is negative; rake is the positive fee taken
      coinByUser[winnerId] += applied; // shown winnings are net of the rake
      if (rake > 0) await this.addHouseRevenue(rake);
    }

    // Ranking economy: every player gains rank points for what they wagered
    // (tier climbs with betting), and we record each player's biggest win.
    for (const p of dealt) {
      const bet = Number(p.bet) || 0;
      if (bet > 0) await this.rankingService.addWager(p.userId, bet);
      const net = coinByUser[p.userId] || 0;
      if (net > 0) await this.rankingService.recordWin(p.userId, net);
    }

    const players = dealt.map((p) => ({
      userId: p.userId,
      seat: p.seat,
      score: scores[p.userId] || 0,
      coins: coinByUser[p.userId] || 0,
      bet: Number(p.bet) || 0,
      front: p.frontHand as Card[],
      middle: p.middleHand as Card[],
      back: p.backHand as Card[],
      frontType: this.gameLogic.evaluate(p.frontHand as Card[]).type,
      middleType: this.gameLogic.evaluate(p.middleHand as Card[]).type,
      backType: this.gameLogic.evaluate(p.backHand as Card[]).type,
      locked: this.gameLogic.isLocked(
        p.frontHand as Card[],
        p.middleHand as Card[],
        p.backHand as Card[],
      ),
      displayName: p.user?.displayName ?? `Seat ${p.seat + 1}`,
    }));

    // Save this round to history for the admin panel.
    await this.historyRepo
      .save(
        this.historyRepo.create({
          roomCode: game.roomCode,
          gameMode: mode,
          winnerName:
            players.find((p) => p.userId === winnerId)?.displayName ?? null,
          data: {
            pot,
            rake,
            wagered: dealt.reduce((s, p) => s + (Number(p.bet) || 0), 0),
            players: players.map((p) => ({
              name: p.displayName,
              score: p.score,
              coins: p.coins,
              locked: p.locked,
              front: p.front,
              middle: p.middle,
              back: p.back,
            })),
          },
        }),
      )
      .catch(() => undefined);

    return { mode, bankerId, scores, winnerId, pot, rake, rowWinners, players };
  }

  /** Which game modes are currently enabled (default all on). */
  async enabledModes(): Promise<Record<string, boolean>> {
    const rows = await this.settingRepo.find();
    const map: Record<string, string> = {};
    for (const r of rows) map[r.key] = r.value;
    return {
      classic: map['mode_classic'] !== 'false',
      banker: map['mode_banker'] !== 'false',
      pot: map['mode_pot'] !== 'false',
    };
  }

  async setModeEnabled(mode: string, enabled: boolean): Promise<void> {
    await this.settingRepo.save({ key: `mode_${mode}`, value: String(enabled) });
  }

  /** Total house earnings (accumulated rake), in coins. */
  async getHouseRevenue(): Promise<number> {
    const row = await this.settingRepo.findOne({ where: { key: 'house_rake' } });
    return Number(row?.value || 0);
  }

  /** Add to the accumulated house rake total. */
  private async addHouseRevenue(amount: number): Promise<void> {
    const current = await this.getHouseRevenue();
    await this.settingRepo.save({
      key: 'house_rake',
      value: String(current + amount),
    });
  }

  /** Aggregate stats for the admin dashboard. */
  async historyStats(): Promise<{
    total: number;
    byMode: Record<string, number>;
    wagered: number;
    rake: number;
  }> {
    const all = await this.historyRepo.find();
    const byMode: Record<string, number> = {};
    let wagered = 0;
    for (const h of all) {
      byMode[h.gameMode] = (byMode[h.gameMode] || 0) + 1;
      wagered += Number(h.data?.wagered || 0);
    }
    const rake = await this.getHouseRevenue();
    return { total: all.length, byMode, wagered, rake };
  }

  /** Recent finished rounds for the admin history view. */
  async getHistory(roomCode?: string): Promise<GameHistory[]> {
    return this.historyRepo.find({
      where: roomCode ? { roomCode } : {},
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  async getRoomState(roomCode: string): Promise<Game | null> {
    return this.gameRepo.findOne({
      where: { roomCode },
      relations: ['players', 'players.user'],
    });
  }

  async getActiveRooms(): Promise<Game[]> {
    // Include in-progress rooms so players can join for the next deal.
    return this.gameRepo.find({
      where: {
        status: In(['waiting', 'betting', 'dealing', 'arranging', 'comparing']),
      },
      relations: ['players', 'players.user'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  /**
   * Cancel waiting rooms whose players are all disconnected (e.g. left over
   * from a previous session), so the lobby never lists ghost rooms.
   */
  async cancelStaleRooms(activeUserIds: string[]): Promise<void> {
    const active = new Set(activeUserIds);
    const rooms = await this.gameRepo.find({
      where: { status: 'waiting' },
      relations: ['players'],
    });
    for (const r of rooms) {
      const someoneHere = (r.players || []).some((p) => active.has(p.userId));
      if (!someoneHere) {
        r.status = 'cancelled';
        await this.gameRepo.save(r);
      }
    }
  }

  /** Remove a (disconnected) user from every waiting room they're seated in. */
  async removeFromWaitingRooms(userId: string): Promise<void> {
    const seats = await this.gpRepo.find({ where: { userId } });
    for (const gp of seats) {
      const game = await this.gameRepo.findOne({ where: { id: gp.gameId } });
      if (!game || game.status !== 'waiting') continue;
      await this.gpRepo.delete({ gameId: game.id, userId });
      const remaining = await this.gpRepo.count({ where: { gameId: game.id } });
      if (remaining === 0) {
        game.status = 'cancelled';
        await this.gameRepo.save(game);
      }
    }
  }
}
