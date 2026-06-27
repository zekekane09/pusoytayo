import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/lobby/domain/room_model.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
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
                  _OnlineCount(count: 1234),
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
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassContainer(
                    padding: const EdgeInsets.all(12),
                    borderRadius: 12,
                    child: const Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RoomsList(rooms: _mockRooms('practice')),
                  _RoomsList(rooms: _mockRooms('competitive')),
                  _RoomsList(rooms: _mockRooms('private')),
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
  const _RoomsList({required this.rooms});

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
        return _RoomCard(room: rooms[index])
            .animate()
            .fadeIn(delay: (index * 80).ms, duration: 400.ms)
            .slideX(begin: 0.05);
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: room.isFull
                      ? [AppColors.error.withValues(alpha: 0.3), AppColors.error.withValues(alpha: 0.1)]
                      : [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.1)],
                ),
              ),
              child: Icon(
                room.isPrivate ? Icons.lock_rounded : Icons.meeting_room_rounded,
                color: room.isFull ? AppColors.error : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${room.code}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.betAmount > 0
                        ? '${room.currency == 'cash' ? '₱' : ''}${room.betAmount} entry'
                        : 'Free play',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${room.currentPlayers}/${room.maxPlayers}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: room.isFull ? AppColors.error : AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room.isFull ? 'Full' : 'Open',
                  style: TextStyle(
                    fontSize: 11,
                    color: room.isFull ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            if (!room.isFull) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.login_rounded, color: AppColors.primary),
                onPressed: () => context.go('/game/${room.code}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
