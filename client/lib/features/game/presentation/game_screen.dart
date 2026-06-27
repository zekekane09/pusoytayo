import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/game_state_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';
import 'package:pusoy_tayo/features/game/logic/hand_comparator.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/card_widget.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/dealing_overlay.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/hand_row.dart';
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
  List<PlayingCard> _selectedCards = [];
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

  // Reveal + history. Next round only deals once you ready up (bots are always
  // ready), so the loop waits for "all players ready" instead of a timer.
  List<PlayerArrangement> _roundArrangements = [];
  ScoringResult? _roundResult;
  final List<_RoundRecord> _history = [];
  bool _youReady = false;

  @override
  void initState() {
    super.initState();
    _dealRound();
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
    if (!_isComplete) _autoArrange();
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
      _selectedCards = [];
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
    _startTimer();
  }

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

  void _toggleCardSelection(PlayingCard card) {
    setState(() {
      if (_selectedCards.contains(card)) {
        _selectedCards.remove(card);
      } else {
        _selectedCards.add(card);
      }
    });
  }

  void _assignToFront() {
    if (_selectedCards.isEmpty) return;
    final currentFront = List<PlayingCard>.from(_gameState.frontHand);
    for (final card in _selectedCards) {
      if (currentFront.length < 3 && !currentFront.contains(card)) {
        currentFront.add(card);
      }
    }
    setState(() {
      _gameState = _gameState.copyWith(frontHand: currentFront);
      _selectedCards = [];
    });
  }

  void _assignToMiddle() {
    if (_selectedCards.isEmpty) return;
    final currentMiddle = List<PlayingCard>.from(_gameState.middleHand);
    for (final card in _selectedCards) {
      if (currentMiddle.length < 5 && !currentMiddle.contains(card)) {
        currentMiddle.add(card);
      }
    }
    setState(() {
      _gameState = _gameState.copyWith(middleHand: currentMiddle);
      _selectedCards = [];
    });
  }

  void _assignToBack() {
    if (_selectedCards.isEmpty) return;
    final currentBack = List<PlayingCard>.from(_gameState.backHand);
    for (final card in _selectedCards) {
      if (currentBack.length < 5 && !currentBack.contains(card)) {
        currentBack.add(card);
      }
    }
    setState(() {
      _gameState = _gameState.copyWith(backHand: currentBack);
      _selectedCards = [];
    });
  }

  void _removeFromHand(PlayingCard card, String hand) {
    setState(() {
      switch (hand) {
        case 'front':
          final updated = List<PlayingCard>.from(_gameState.frontHand)..remove(card);
          _gameState = _gameState.copyWith(frontHand: updated);
        case 'middle':
          final updated = List<PlayingCard>.from(_gameState.middleHand)..remove(card);
          _gameState = _gameState.copyWith(middleHand: updated);
        case 'back':
          final updated = List<PlayingCard>.from(_gameState.backHand)..remove(card);
          _gameState = _gameState.copyWith(backHand: updated);
      }
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
      _selectedCards = [];
    });
  }

  void _resetArrangement() {
    setState(() {
      _gameState = _gameState.copyWith(
        frontHand: [],
        middleHand: [],
        backHand: [],
      );
      _selectedCards = [];
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

    return Scaffold(
      body: TableBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(),
                  _buildPlayersRow(),
                  _buildStatusLine(),
                  const SizedBox(height: 6),
                  if (isReveal)
                    Expanded(child: _buildRevealView())
                  else ...[
                    _buildArrangementArea(),
                    const Spacer(),
                    _buildCardFan(),
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
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Text(
            '🏆  Winner: ${_gameState.players[winnerIdx].displayName}'
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
            onPressed: () => Navigator.of(context).pop(),
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
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildStatusLine() {
    final myTotal = _totalScores[0] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _bankerMode
                ? '👑 Banker: ${_gameState.players[_bankerIndex].displayName}'
                : 'Free-for-all  •  ${_playerCount}P',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Round $_round   •   Total ${myTotal >= 0 ? '+$myTotal' : '$myTotal'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openConfig() {
    int tmpPlayers = _playerCount;
    bool tmpBanker = _bankerMode;
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.success,
                title: const Text('Banker Mode',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text(
                  'Everyone plays only against the banker',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                value: tmpBanker,
                onChanged: (v) => setSheet(() => tmpBanker = v),
              ),
              const SizedBox(height: 12),
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
                      _bankerMode = tmpBanker;
                      _round = 1;
                      _totalScores.clear();
                      _history.clear();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          HandRow(
            label: 'FRONT (Weakest)',
            maxCards: 3,
            cards: _gameState.frontHand,
            onRemoveCard: (card) => _removeFromHand(card, 'front'),
            labelColor: AppColors.info,
          ),
          const SizedBox(height: 6),
          HandRow(
            label: 'MIDDLE',
            maxCards: 5,
            cards: _gameState.middleHand,
            onRemoveCard: (card) => _removeFromHand(card, 'middle'),
            labelColor: AppColors.warning,
          ),
          const SizedBox(height: 6),
          HandRow(
            label: 'BACK (Strongest)',
            maxCards: 5,
            cards: _gameState.backHand,
            onRemoveCard: (card) => _removeFromHand(card, 'back'),
            labelColor: AppColors.error,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildCardFan() {
    final unassigned = _gameState.unassignedCards;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: unassigned.isEmpty
          ? Center(
              child: Text(
                _isComplete ? 'All cards assigned!' : 'No cards remaining',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: unassigned.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final card = unassigned[index];
                final isSelected = _selectedCards.contains(card);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: CardWidget(
                    card: card,
                    isSelected: isSelected,
                    width: 55,
                    height: 78,
                    onTap: () => _toggleCardSelection(card),
                  ),
                ).animate().fadeIn(
                      delay: (index * 40).ms,
                      duration: 300.ms,
                    );
              },
            ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            label: 'Auto',
            icon: Icons.auto_fix_high_rounded,
            onTap: _autoArrange,
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: 'Reset',
            icon: Icons.refresh_rounded,
            onTap: _resetArrangement,
          ),
          const SizedBox(width: 6),
          if (_selectedCards.isNotEmpty) ...[
            _ActionButton(
              label: 'Front',
              icon: Icons.arrow_upward,
              onTap: _assignToFront,
              color: AppColors.info,
            ),
            const SizedBox(width: 4),
            _ActionButton(
              label: 'Mid',
              icon: Icons.remove,
              onTap: _assignToMiddle,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            _ActionButton(
              label: 'Back',
              icon: Icons.arrow_downward,
              onTap: _assignToBack,
              color: AppColors.error,
            ),
          ],
          const Spacer(),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: (_isComplete && !_submitted) ? _submitArrangement : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (_isComplete && !_submitted)
                    ? AppColors.success
                    : AppColors.surfaceLight,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceLight,
                disabledForegroundColor: AppColors.textMuted,
              ),
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text(_submitted ? 'Submitted' : 'Submit'),
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
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
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
