import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/constants/socket_events.dart';
import 'package:pusoy_tayo/core/network/api_client.dart';
import 'package:pusoy_tayo/core/network/socket_client.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/lobby/domain/room_model.dart';
import 'package:pusoy_tayo/features/wallet/data/wallet_provider.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<StreamSubscription> _subs = [];
  List<RoomModel> _onlineRooms = [];
  bool _connecting = false;
  Timer? _refreshTimer;
  Map<String, bool> _modes = {'classic': true, 'banker': true, 'pot': true};

  @override
  void initState() {
    super.initState();
    // Default to the online (Competitive) tab so rooms others created show up.
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _loadModes();
    _connectAndList();
  }

  void _refreshRooms() {
    ref.read(socketClientProvider).emit(SocketEvents.lobbyList);
  }

  Future<void> _loadModes() async {
    try {
      final res = await ref.read(apiClientProvider).get('/admin/modes');
      final m = res.data as Map;
      if (mounted) {
        setState(() => _modes = {
              'classic': m['classic'] != false,
              'banker': m['banker'] != false,
              'pot': m['pot'] != false,
            });
      }
    } catch (_) {}
  }

  Future<void> _connectAndList() async {
    setState(() => _connecting = true);
    final socket = ref.read(socketClientProvider);
    await socket.connect();
    _subs.add(socket.on<dynamic>(SocketEvents.lobbyRoomsList).listen((d) {
      final list = ((d as Map)['rooms'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _onlineRooms = list.map((r) {
          final m = (r as Map);
          return RoomModel(
            code: m['code'].toString(),
            status: m['status']?.toString() ?? 'waiting',
            gameMode: m['gameMode']?.toString() ?? 'classic',
            betAmount: int.tryParse('${m['betAmount']}') ?? 0,
            currency: m['currency']?.toString() ?? 'coins',
            maxPlayers: (m['maxPlayers'] as num?)?.toInt() ?? 4,
            currentPlayers: (m['currentPlayers'] as num?)?.toInt() ?? 0,
            createdBy: 'host',
            hostName: m['hostName']?.toString() ?? 'Host',
            isPrivate: false,
            createdAt: DateTime.now(),
          );
        }).toList();
      });
    }));
    _subs.add(socket.on<dynamic>(SocketEvents.lobbyRoomCreated).listen((d) {
      final code = (d as Map)['code']?.toString();
      if (code != null && mounted) context.go('/online/$code');
    }));
    _subs.add(socket.on<dynamic>(SocketEvents.lobbyError).listen((d) {
      final msg = (d as Map)['message']?.toString() ?? 'Error';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }));
    // Friend game-invites are handled app-wide in ShellScaffold, so they reach
    // the player on any screen (not just the lobby).
    socket.emit(SocketEvents.lobbyList);

    // Poll periodically so newly created rooms on other devices appear even if
    // a broadcast was missed (e.g. during a brief reconnect).
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _refreshRooms();
    });
  }

  void _quickMatch() {
    final socket = ref.read(socketClientProvider);
    // Join the first open online room, or create a fresh central-pot room.
    final open = _onlineRooms
        .where((r) => !r.isFull && r.status == 'waiting')
        .toList();
    if (open.isNotEmpty) {
      context.go('/online/${open.first.code}');
    } else {
      socket.emit(SocketEvents.lobbyCreate,
          {'gameMode': 'pot', 'betAmount': 0, 'currency': 'coins'});
    }
  }

  void _showCreateRoomDialog() {
    // Only offer enabled modes (admin can disable them).
    final modeOptions = [
      if (_modes['classic'] != false)
        ('classic', '🎮 Free-for-All', 'Everyone competes against everyone.'),
      if (_modes['banker'] != false)
        ('banker', '👑 Banker',
            'You are the Banker; everyone plays only against you.'),
      if (_modes['pot'] != false)
        ('pot', '🪙 Central Pot', 'Everyone antes; winner takes the pot.'),
    ];
    if (modeOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No game modes are enabled right now.')),
      );
      return;
    }
    String mode = modeOptions.first.$1;
    int bet = 0;
    int players = 4;
    final coins = ref.read(walletProvider).valueOrNull?.coins ?? 0;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Banker must cover the worst case: every opponent scooping (×6).
          // Each player risks only their bet, so the banker covers (players-1)×bet.
          final liability = mode == 'banker' ? (players - 1) * bet : 0;
          final canAfford = mode != 'banker' || coins >= liability;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Room',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                const Text('Select Game Mode',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (final m in modeOptions)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setSheet(() => mode = m.$1),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: mode == m.$1
                                  ? AppColors.gold
                                  : AppColors.glassBorder,
                              width: mode == m.$1 ? 2 : 1,
                            ),
                            color: mode == m.$1
                                ? AppColors.gold.withValues(alpha: 0.08)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                mode == m.$1
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: mode == m.$1
                                    ? AppColors.gold
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(m.$2,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700)),
                                    Text(m.$3,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Players',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in const [2, 3, 4])
                      ChoiceChip(
                        label: Text('$n'),
                        selected: players == n,
                        onSelected: (_) => setSheet(() => players = n),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Entry (coins)',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in const [0, 10, 25, 50, 100])
                      ChoiceChip(
                        label: Text(b == 0 ? 'Free' : '$b'),
                        selected: bet == b,
                        onSelected: (_) => setSheet(() => bet = b),
                      ),
                  ],
                ),
                if (mode == 'banker' && bet > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Your balance: $coins  •  Required bankroll: $liability',
                    style: TextStyle(
                        color: canAfford ? AppColors.textMuted : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  if (!canAfford)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Insufficient balance to act as Banker.',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: canAfford
                        ? () {
                            Navigator.of(ctx).pop();
                            ref.read(socketClientProvider).emit(
                              SocketEvents.lobbyCreate,
                              {
                                'gameMode': mode,
                                'betAmount': bet,
                                'currency': 'coins',
                                'maxPlayers': players,
                              },
                            );
                          }
                        : null,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Create Room'),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'GAME LOBBY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Refresh rooms',
                    onPressed: _refreshRooms,
                  ),
                  _OnlineCount(count: _onlineRooms.length),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: const [
                Tab(text: 'Practice'),
                Tab(text: 'Competitive'),
                Tab(text: 'Private'),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Quick Match',
                      icon: Icons.flash_on_rounded,
                      onPressed: _quickMatch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showCreateRoomDialog,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 12,
                      child:
                          const Icon(Icons.add, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RoomsList(rooms: _mockRooms('practice'), online: false),
                  _connecting
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : _RoomsList(rooms: _onlineRooms, online: true),
                  _RoomsList(rooms: _mockRooms('private'), online: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RoomModel> _mockRooms(String mode) {
    return List.generate(
      5,
      (i) => RoomModel(
        code: 'ROOM${i + 1}',
        status: 'waiting',
        gameMode: mode,
        betAmount: mode == 'practice' ? 0 : (i + 1) * 100,
        currency: mode == 'practice' ? 'coins' : 'cash',
        maxPlayers: 4,
        currentPlayers: i % 3 + 1,
        createdBy: 'Player${i + 1}',
        isPrivate: mode == 'private',
        createdAt: DateTime.now(),
      ),
    );
  }
}

class _OnlineCount extends StatelessWidget {
  final int count;
  const _OnlineCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count online',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsList extends StatelessWidget {
  final List<RoomModel> rooms;
  final bool online;
  const _RoomsList({required this.rooms, required this.online});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No rooms available',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        return _RoomCard(room: rooms[index], online: online)
            .animate()
            .fadeIn(delay: (index * 80).ms, duration: 400.ms)
            .slideX(begin: 0.05);
      },
    );
  }
}

class _RoomCard extends ConsumerWidget {
  final RoomModel room;
  final bool online;
  const _RoomCard({required this.room, required this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The whole row is tappable to enter the room.
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    void join() {
      // Block joining a staked room with no coins.
      if (online && room.betAmount > 0 && coins <= 0) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text("Can't join",
                style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'You have 0 coins. Add coins before joining a paid room.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      context.go('${online ? '/online' : '/game'}/${room.code}');
    }

    final onTap = room.isFull ? null : join;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: (room.isBanker
                            ? AppColors.gold
                            : AppColors.primary)
                        .withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    room.isPrivate
                        ? Icons.lock_rounded
                        : Icons.meeting_room_rounded,
                    size: 18,
                    color: room.isFull
                        ? AppColors.error
                        : (room.isBanker
                            ? AppColors.gold
                            : AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('Room ${room.code}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          if (room.betAmount > 0) ...[
                            const SizedBox(width: 8),
                            Text('${room.betAmount} entry',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      if (online)
                        Text(
                          room.isBanker
                              ? '${room.modeLabel} • ${room.hostName}'
                              : room.modeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: room.isBanker
                                ? AppColors.gold
                                : AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${room.currentPlayers}/${room.maxPlayers}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: room.isFull ? AppColors.error : AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  room.isFull ? Icons.block_rounded : Icons.login_rounded,
                  size: 18,
                  color: room.isFull ? AppColors.error : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
