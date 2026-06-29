import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/game_state_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';
import 'package:pusoy_tayo/features/game/logic/hand_comparator.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/card_widget.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/dealing_overlay.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/opponent_fan.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/player_reveal.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/player_slot.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/table_background.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const GameScreen({super.key, required this.roomCode});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  late GameState _gameState;
  int _timerSeconds = 300; // 5-minute arrangement timer
  Timer? _timer;
  bool _submitted = false;
  List<List<PlayingCard>> _opponentHands = [];

  // Table config + running match state
  int _playerCount = 4;
  bool _bankerMode = false;
  int _bankerIndex = 0;
  int _round = 1;
  final Map<int, int> _totalScores = {};

  // Betting. Each point won/lost is worth [_betChips] chips. In Central Pot
  // mode every player antes [_betChips] into a shared pot the round winner
  // takes. Banker mode lets you raise/lower your stake before the deal locks.
  static const int _minBet = 5;
  static const int _maxBet = 200;
  static const int _betStep = 5;
  static const int _startingChips = 1000;
  int _betChips = 10;
  bool _centralPot = false;
  final Map<int, int> _balances = {};
  int _lastPot = 0;

  // Reveal + history. Next round only deals once you ready up (bots are always
  // ready), so the loop waits for "all players ready" instead of a timer.
  List<PlayerArrangement> _roundArrangements = [];
  ScoringResult? _roundResult;
  final List<_RoundRecord> _history = [];
  bool _youReady = false;

  @override
  void initState() {
    super.initState();
    _resetBalances();
    _dealRound();
  }

  void _resetBalances() {
    _balances.clear();
    for (int i = 0; i < _playerCount; i++) {
      _balances[i] = _startingChips;
    }
    _lastPot = 0;
  }

  void _changeBet(int delta) {
    setState(() {
      _betChips = (_betChips + delta).clamp(_minBet, _maxBet);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timerSeconds > 0) _timerSeconds--;
      });
      if (_timerSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    if (_submitted) return;
    // Out of time: snap to a legal arrangement so we never auto-submit a foul.
    if (!_isComplete || !_isValidArrangement) _autoArrange();
    _submitArrangement(force: true);
  }

  /// Shuffles a fresh deck and deals a new round to all [_playerCount] players.
  /// Enters the `dealing` phase; the deal animation drives the move to
  /// `arranging` (see [_onDealComplete]).
  void _dealRound() {
    final deck = PlayingCard.fullDeck()..shuffle(Random());
    final myCards = deck.sublist(0, 13)..sort();
    _opponentHands = [
      for (int i = 1; i < _playerCount; i++) deck.sublist(i * 13, i * 13 + 13),
    ];

    if (_bankerMode) {
      _bankerIndex = (_round - 1) % _playerCount;
    }

    final players = <GamePlayer>[
      const GamePlayer(id: '0', displayName: 'You', seat: 0, isReady: true),
      for (int i = 1; i < _playerCount; i++)
        GamePlayer(
          id: '$i',
          displayName: 'Player ${i + 1}',
          seat: i,
          isReady: true,
        ),
    ];

    _timer?.cancel();

    setState(() {
      _gameState = GameState(
        roomCode: widget.roomCode,
        phase: GamePhase.dealing,
        players: players,
        myCards: myCards,
      );
      _submitted = false;
      _youReady = false;
      _timerSeconds = 300;
    });
  }

  /// Called by the DealingOverlay once the distribution animation finishes.
  void _onDealComplete() {
    if (!mounted || _gameState.phase != GamePhase.dealing) return;
    setState(() {
      _gameState = _gameState.copyWith(phase: GamePhase.arranging);
    });
    _autoArrange(); // start pre-arranged; the player drags cards to swap them
    _startTimer();
  }

  /// Swap two placed cards (within or across rows). Row sizes are preserved.
  void _swapCards(PlayingCard a, PlayingCard b) {
    if (a == b) return;
    final f = List<PlayingCard>.from(_gameState.frontHand);
    final m = List<PlayingCard>.from(_gameState.middleHand);
    final bk = List<PlayingCard>.from(_gameState.backHand);
    List<PlayingCard>? rowOf(PlayingCard c) => f.contains(c)
        ? f
        : m.contains(c)
            ? m
            : bk.contains(c)
                ? bk
                : null;
    final ra = rowOf(a);
    final rb = rowOf(b);
    if (ra == null || rb == null) return;
    ra[ra.indexOf(a)] = b;
    rb[rb.indexOf(b)] = a;
    setState(() {
      _gameState =
          _gameState.copyWith(frontHand: f, middleHand: m, backHand: bk);
    });
  }

  /// Swap the whole middle and bottom rows (both 5 cards) — handy when the
  /// middle is stronger than the bottom.
  void _swapMiddleBack() {
    setState(() {
      _gameState = _gameState.copyWith(
        middleHand: List<PlayingCard>.from(_gameState.backHand),
        backHand: List<PlayingCard>.from(_gameState.middleHand),
      );
    });
  }

  bool get _backWeakerThanMiddle =>
      _gameState.backHand.isNotEmpty &&
      _gameState.middleHand.isNotEmpty &&
      HandEvaluator.evaluate(_gameState.backHand)
              .compareTo(HandEvaluator.evaluate(_gameState.middleHand)) <
          0;

  void _nextRound() {
    _round++;
    _dealRound();
  }

  void _readyUp() {
    // You readied up; the bots are always ready, so the table is full —
    // deal the next round.
    setState(() => _youReady = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _gameState.phase == GamePhase.comparing) _nextRound();
    });
  }

  /// Splits 13 cards into a sensible arrangement: the strongest cards go to the
  /// BACK row and the weakest to the FRONT row (so front <= middle <= back).
  (List<PlayingCard>, List<PlayingCard>, List<PlayingCard>) _arrangeCards(
    List<PlayingCard> cards,
  ) {
    final sorted = List<PlayingCard>.from(cards)..sort(); // ascending: weakest first
    final front = sorted.sublist(0, 3);
    final middle = sorted.sublist(3, 8);
    final back = sorted.sublist(8, 13);
    return (front, middle, back);
  }

  /// Always-valid arrangement: the strongest 5-card hand goes to BACK, the
  /// strongest 5 of the remaining 8 to MIDDLE, and the last 3 to FRONT — which
  /// is back >= middle >= front by construction for virtually every hand.
  (List<PlayingCard>, List<PlayingCard>, List<PlayingCard>) _validArrangement(
    List<PlayingCard> cards,
  ) {
    final back = _strongestFive(cards);
    final rem8 = [for (final c in cards) if (!back.contains(c)) c];
    final middle = _strongestFive(rem8);
    final front = [for (final c in rem8) if (!middle.contains(c)) c];
    if (!HandEvaluator.isValidArrangement(front, middle, back)) {
      return _arrangeCards(cards); // extremely rare fallback
    }
    return (front, middle, back);
  }

  /// Returns the strongest 5-card poker hand within [cards].
  List<PlayingCard> _strongestFive(List<PlayingCard> cards) {
    final n = cards.length;
    List<PlayingCard>? best;
    HandResult? bestRes;
    for (int a = 0; a < n - 4; a++) {
      for (int b = a + 1; b < n - 3; b++) {
        for (int c = b + 1; c < n - 2; c++) {
          for (int d = c + 1; d < n - 1; d++) {
            for (int e = d + 1; e < n; e++) {
              final hand = [cards[a], cards[b], cards[c], cards[d], cards[e]];
              final res = HandEvaluator.evaluate(hand);
              if (best == null || res.compareTo(bestRes!) > 0) {
                best = hand;
                bestRes = res;
              }
            }
          }
        }
      }
    }
    return best ?? cards.take(5).toList();
  }

  void _autoArrange() {
    final (front, middle, back) = _validArrangement(_gameState.myCards);
    setState(() {
      _gameState = _gameState.copyWith(
        frontHand: front,
        middleHand: middle,
        backHand: back,
      );
    });
  }

  bool get _isValidArrangement {
    return HandEvaluator.isValidArrangement(
      _gameState.frontHand,
      _gameState.middleHand,
      _gameState.backHand,
    );
  }

  bool get _isComplete {
    return _gameState.frontHand.length == 3 &&
        _gameState.middleHand.length == 5 &&
        _gameState.backHand.length == 5;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.warning),
    );
  }

  void _submitArrangement({bool force = false}) {
    if (_submitted) return;
    if (!_isComplete && !force) {
      _snack('Assign all 13 cards first');
      return;
    }
    if (!force && !_isValidArrangement) {
      _snack('Invalid: Back must be ≥ Middle must be ≥ Front');
      return;
    }

    _timer?.cancel();

    // Build everyone's arrangement (you + auto-arranged bots) and score it.
    final arrangements = <PlayerArrangement>[
      PlayerArrangement(
        playerIndex: 0,
        front: _gameState.frontHand,
        middle: _gameState.middleHand,
        back: _gameState.backHand,
      ),
    ];
    for (int i = 0; i < _opponentHands.length; i++) {
      final (f, m, b) = _validArrangement(_opponentHands[i]);
      arrangements.add(
        PlayerArrangement(playerIndex: i + 1, front: f, middle: m, back: b),
      );
    }

    final result = _bankerMode
        ? HandComparator.calculateBankerScores(arrangements, _bankerIndex)
        : HandComparator.calculateScores(arrangements);

    result.scores.forEach((k, v) {
      _totalScores[k] = (_totalScores[k] ?? 0) + v;
    });

    // Settle chips. Central Pot: everyone antes, the round winner takes the
    // whole pot. Otherwise each point is worth [_betChips].
    int pot = 0;
    if (_centralPot) {
      final winner = result.scores.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      pot = _betChips * _playerCount;
      for (int i = 0; i < _playerCount; i++) {
        _balances[i] =
            (_balances[i] ?? _startingChips) - _betChips + (i == winner ? pot : 0);
      }
    } else {
      result.scores.forEach((k, v) {
        _balances[k] = (_balances[k] ?? _startingChips) + v * _betChips;
      });
    }
    _lastPot = pot;

    setState(() {
      _submitted = true;
      _youReady = false;
      _roundArrangements = arrangements;
      _roundResult = result;
      _gameState = _gameState.copyWith(phase: GamePhase.comparing);
      _history.insert(
        0,
        _RoundRecord(
          round: _round,
          bankerIndex: _bankerMode ? _bankerIndex : null,
          names: [for (final p in _gameState.players) p.displayName],
          arrangements: arrangements,
          scores: Map<int, int>.from(result.scores),
          totals: Map<int, int>.from(_totalScores),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final phase = _gameState.phase;
    final isReveal = phase == GamePhase.comparing;
    final isDealing = phase == GamePhase.dealing;

    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: TableBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Landscape: opponents sit on the felt behind the arrangement
              // (more room to arrange), face-down until everyone is ready.
              if (landscape)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _opponentsBackground(reveal: isReveal),
                  ),
                ),
              Column(
                children: [
                  _buildTopBar(),
                  if (!landscape) _buildPlayersRow(),
                  _buildStatusLine(),
                  if ((_bankerMode || _centralPot) &&
                      phase == GamePhase.arranging)
                    _buildBetBar(),
                  const SizedBox(height: 6),
                  if (isReveal && !landscape)
                    Expanded(child: _buildRevealView())
                  else ...[
                    // Cards start pre-arranged; drag any card onto another to
                    // swap them. Once you're Ready your cards shrink to the
                    // same grouped size as the other players.
                    Expanded(
                      child: (isReveal && landscape)
                          ? Align(
                              alignment: const Alignment(0, 1.0),
                              child: _myGroupedFan())
                          : _buildArrangementArea(),
                    ),
                    if (isReveal)
                      _buildRevealControls()
                    else
                      _buildActionBar(),
                  ],
                ],
              ),
              if (isDealing)
                Positioned.fill(
                  child: DealingOverlay(
                    playerCount: _playerCount,
                    onDone: _onDealComplete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opponents arranged around the felt (landscape). Each shows their 13 cards
  /// face-down while arranging, flipping face-up once [reveal] is true.
  Widget _opponentsBackground({required bool reveal}) {
    final others = <({String name, List<PlayingCard> f, List<PlayingCard> m, List<PlayingCard> b})>[];
    for (int i = 1; i < _playerCount; i++) {
      List<PlayingCard> f, m, b;
      if (reveal && i < _roundArrangements.length) {
        final a = _roundArrangements[i];
        f = a.front;
        m = a.middle;
        b = a.back;
      } else {
        // Face-down placeholder: split their sorted hand into 3 / 5 / 5.
        final s = List<PlayingCard>.from(_opponentHands[i - 1])..sort();
        f = s.sublist(0, 3);
        m = s.sublist(3, 8);
        b = s.sublist(8, 13);
      }
      others.add((name: _gameState.players[i].displayName, f: f, m: m, b: b));
    }
    final aligns = switch (others.length) {
      1 => const [Alignment(0, -0.92)],
      2 => const [Alignment(-0.92, -0.5), Alignment(0.92, -0.5)],
      _ => const [
          Alignment(0, -0.98),
          Alignment(-0.96, -0.1),
          Alignment(0.96, -0.1),
        ],
    };
    return Stack(
      children: [
        for (int i = 0; i < others.length && i < aligns.length; i++)
          Align(
            alignment: aligns[i],
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: reveal ? 1.0 : 0.6,
              child: OpponentFan(
                name: others[i].name,
                front: others[i].f,
                middle: others[i].m,
                back: others[i].b,
                reveal: reveal,
                scale: reveal ? 1.05 : 0.9,
              ),
            ),
          ),
      ],
    );
  }

  /// My hand shown as the same compact grouped stacks as the opponents (used
  /// once I'm Ready, so everyone's cards match in size).
  Widget _myGroupedFan() {
    return OpponentFan(
      name: 'You',
      front: _gameState.frontHand,
      middle: _gameState.middleHand,
      back: _gameState.backHand,
      reveal: true,
      scale: 1.3,
    );
  }

  Widget _buildRevealControls() {
    final myScore = _roundResult?.scores[0] ?? 0;
    final txt = myScore > 0
        ? 'You Win +$myScore'
        : (myScore < 0 ? 'You Lose $myScore' : 'Even');
    final col = myScore > 0
        ? AppColors.success
        : (myScore < 0 ? AppColors.error : AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(txt,
              style: TextStyle(
                  color: col, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded,
                color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: _youReady ? null : _readyUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(_youReady ? 'Waiting…' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealView() {
    final result = _roundResult;
    if (result == null) return const SizedBox.shrink();
    final myScore = result.scores[0] ?? 0;

    final String title;
    final Color titleColor;
    if (result.scoopWinner == 0) {
      title = 'SCOOP! You swept the table';
      titleColor = AppColors.success;
    } else if (myScore > 0) {
      title = 'You Win  (+$myScore)';
      titleColor = AppColors.success;
    } else if (myScore < 0) {
      title = 'You Lose  ($myScore)';
      titleColor = AppColors.error;
    } else {
      title = 'Even';
      titleColor = AppColors.warning;
    }

    final winnerIdx =
        result.scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final order = result.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_centralPot && _lastPot > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              '🪙  Center Pot: $_lastPot chips  →  ${_gameState.players[winnerIdx].displayName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Text(
            '💰  ${_gameState.players[0].displayName}: ${_balances[0] ?? _startingChips} chips'
            '     •     🏆 ${_gameState.players[winnerIdx].displayName}'
            '  (+${result.scores[winnerIdx] ?? 0})',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final e in order)
                PlayerRevealTile(
                  name: _gameState.players[e.key].displayName,
                  arr: _roundArrangements[e.key],
                  roundScore: e.value,
                  total: _totalScores[e.key] ?? 0,
                  isYou: e.key == 0,
                  isBanker: _bankerMode && e.key == _bankerIndex,
                  isWinner: e.key == winnerIdx,
                ),
            ],
          ),
        ),
        _buildRevealFooter(),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildRevealFooter() {
    final readyCount = (_playerCount - 1) + (_youReady ? 1 : 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => context.go('/lobby'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            child: const Text('Leave'),
          ),
          const Spacer(),
          Text(
            '$readyCount/$_playerCount ready',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _youReady ? null : _readyUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceLight,
              disabledForegroundColor: AppColors.textMuted,
            ),
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(_youReady ? 'Waiting…' : "I'm Ready"),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Round History',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? const Center(
                      child: Text('No rounds played yet',
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _history.length,
                      itemBuilder: (ctx, i) {
                        final r = _history[i];
                        final winnerIdx = r.scores.entries
                            .reduce((a, b) => a.value >= b.value ? a : b)
                            .key;
                        final order = r.scores.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 12, bottom: 4, left: 4),
                              child: Text(
                                'Round ${r.round}'
                                '${r.bankerIndex != null ? '   •   👑 ${r.names[r.bankerIndex!]}' : ''}',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            for (final e in order)
                              PlayerRevealTile(
                                name: r.names[e.key],
                                arr: r.arrangements[e.key],
                                roundScore: e.value,
                                total: r.totals[e.key] ?? 0,
                                isYou: e.key == 0,
                                isBanker: r.bankerIndex == e.key,
                                isWinner: e.key == winnerIdx,
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.go('/lobby'),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Room ${widget.roomCode}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _gameState.phase.name.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Round history',
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Table settings',
            onPressed: _openConfig,
          ),
          _TimerBadge(seconds: _timerSeconds),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBetBar() {
    final locked = _submitted;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.casino_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            _centralPot ? 'Your ante' : 'Your bet',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _betStepButton(Icons.remove_rounded,
              locked || _betChips <= _minBet ? null : () => _changeBet(-_betStep)),
          Container(
            width: 56,
            alignment: Alignment.center,
            child: Text(
              '$_betChips',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _betStepButton(Icons.add_rounded,
              locked || _betChips >= _maxBet ? null : () => _changeBet(_betStep)),
        ],
      ),
    );
  }

  Widget _betStepButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null
          ? AppColors.surfaceLight
          : AppColors.gold.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 20,
              color: onTap == null ? AppColors.textMuted : AppColors.gold),
        ),
      ),
    );
  }

  Widget _buildStatusLine() {
    final myChips = _balances[0] ?? _startingChips;
    final String mode = _centralPot
        ? '🪙 Central Pot  •  ${_playerCount}P'
        : _bankerMode
            ? '👑 Banker: ${_gameState.players[_bankerIndex].displayName}'
            : 'Free-for-all  •  ${_playerCount}P';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            mode,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 4),
              Text(
                '$myChips',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R$_round',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openConfig() {
    int tmpPlayers = _playerCount;
    // Table mode: 0 = free-for-all, 1 = banker, 2 = central pot.
    int tmpMode = _centralPot ? 2 : (_bankerMode ? 1 : 0);
    int tmpBet = _betChips;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Table Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Players',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final n in [2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$n Players'),
                        selected: tmpPlayers == n,
                        onSelected: (_) => setSheet(() => tmpPlayers = n),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Mode',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [
                    (0, 'Free-for-all'),
                    (1, 'Banker'),
                    (2, 'Central Pot'),
                  ])
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: tmpMode == m.$1,
                      onSelected: (_) => setSheet(() => tmpMode = m.$1),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tmpMode == 2
                    ? 'Everyone antes into a shared pot; the round winner takes it all.'
                    : tmpMode == 1
                        ? 'Everyone plays only against the rotating banker.'
                        : 'Each player scores against every other player.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (tmpMode != 0) ...[
                const SizedBox(height: 14),
                Text(tmpMode == 2 ? 'Ante (chips)' : 'Bet per point (chips)',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in const [5, 10, 25, 50, 100])
                      ChoiceChip(
                        label: Text('$b'),
                        selected: tmpBet == b,
                        onSelected: (_) => setSheet(() => tmpBet = b),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'You can still raise or lower it each round before you submit.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _playerCount = tmpPlayers;
                      _bankerMode = tmpMode == 1;
                      _centralPot = tmpMode == 2;
                      _betChips = tmpBet.clamp(_minBet, _maxBet);
                      _round = 1;
                      _totalScores.clear();
                      _history.clear();
                      _resetBalances();
                    });
                    _dealRound();
                  },
                  icon: const Icon(Icons.casino_rounded),
                  label: const Text('Apply & Deal New Game'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _gameState.players.map((player) {
          return PlayerSlot(
            player: player,
            seatIndex: player.seat,
            isCurrentPlayer: player.seat == 0,
            isCurrentTurn: _bankerMode && player.seat == _bankerIndex,
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildArrangementArea() {
    final front = _gameState.frontHand;
    final middle = _gameState.middleHand;
    final back = _gameState.backHand;
    final midOk = middle.isEmpty ||
        front.isEmpty ||
        HandEvaluator.evaluate(middle).compareTo(HandEvaluator.evaluate(front)) >=
            0;
    final backOk = back.isEmpty ||
        middle.isEmpty ||
        HandEvaluator.evaluate(back).compareTo(HandEvaluator.evaluate(middle)) >=
            0;
    return Align(
      alignment: const Alignment(0, 0.55), // sit low on the table
      child: LayoutBuilder(
        builder: (context, box) {
          // Compact while arranging; the reveal is what gets bigger.
          final cw = ((box.maxWidth - 130) / 6).clamp(32.0, 48.0).toDouble();
          final ch = cw * 1.38;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _swapRow(front, const Color(0xFF31C36E), true, cw, ch),
              const SizedBox(height: 8),
              _swapRow(middle, const Color(0xFF31C36E), midOk, cw, ch),
              const SizedBox(height: 8),
              _swapRow(back, const Color(0xFF8A5A3B), backOk, cw, ch),
            ],
          );
        },
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _swapRow(
      List<PlayingCard> cards, Color border, bool ok, double cw, double ch) {
    final type =
        cards.isEmpty ? '' : HandEvaluator.evaluate(cards).type.displayName;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel,
                  color: ok ? AppColors.success : AppColors.error, size: 26),
              const SizedBox(height: 2),
              Text(type,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 2),
            color: Colors.black.withValues(alpha: 0.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _swapSlot(c, cw, ch),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swapSlot(PlayingCard card, double w, double h) {
    // AnimatedSwitcher keyed by the card cross-fades/scales when a swap changes
    // which card sits in this slot, so swaps feel smooth instead of snapping.
    final cardWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.0).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: CardWidget(
          key: ValueKey(card.toString()), card: card, width: w, height: h),
    );
    if (_submitted) return cardWidget;
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (d) => d.data != card,
      onAcceptWithDetails: (d) => _swapCards(d.data, card),
      builder: (ctx, cand, rej) {
        final hover = cand.isNotEmpty;
        return Draggable<PlayingCard>(
          data: card,
          dragAnchorStrategy: childDragAnchorStrategy,
          feedback: _dragFeedback(card, w, h),
          childWhenDragging: Opacity(opacity: 0.22, child: cardWidget),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: hover ? 1.06 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hover ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
              child: cardWidget,
            ),
          ),
        );
      },
    );
  }

  Widget _dragFeedback(PlayingCard card, double w, double h) {
    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: 0.04,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Transform.scale(
            scale: 1.12,
            child: CardWidget(card: card, width: w, height: h),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final valid = _isValidArrangement;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            label: 'Reshuffle',
            icon: Icons.autorenew_rounded,
            onTap: _autoArrange,
          ),
          if (_backWeakerThanMiddle && !_submitted) ...[
            const SizedBox(width: 6),
            _ActionButton(
              label: 'Swap M/B',
              icon: Icons.swap_vert_rounded,
              onTap: _swapMiddleBack,
            ),
          ],
          if (!valid && !_submitted)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text('Bottom must be highest',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              // Can only ready up with a legal arrangement (back ≥ middle ≥
              // front). Dragging stays free so you can experiment first.
              onPressed: (_isComplete && !_submitted && valid)
                  ? _submitArrangement
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8BC34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceLight,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                  _submitted ? 'Waiting…' : (valid ? 'Ready' : 'Fix order'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 300.ms).slideY(begin: 0.2);
  }
}

class _TimerBadge extends StatelessWidget {
  final int seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isLow = seconds <= 15;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isLow ? AppColors.error : AppColors.accent).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isLow ? AppColors.error : AppColors.accent).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: isLow ? AppColors.error : AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color: isLow ? AppColors.error : AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color = null;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.textMuted).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (color ?? AppColors.glassBorder).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundRecord {
  final int round;
  final int? bankerIndex;
  final List<String> names;
  final List<PlayerArrangement> arrangements;
  final Map<int, int> scores;
  final Map<int, int> totals;

  _RoundRecord({
    required this.round,
    required this.bankerIndex,
    required this.names,
    required this.arrangements,
    required this.scores,
    required this.totals,
  });
}
