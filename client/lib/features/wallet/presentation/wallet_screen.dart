import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/core/constants/api_endpoints.dart';
import 'package:pusoy_tayo/core/network/api_client.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/auth/presentation/auth_controller.dart';
import 'package:pusoy_tayo/features/wallet/data/wallet_provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2818), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Text(
                'WALLET',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WalletBalanceCard()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Deposit',
                          icon: Icons.add_circle_outline,
                          colors: [AppColors.success, const Color(0xFF00C853)],
                          onPressed: () => _showDepositSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(
                          label: 'Withdraw',
                          icon: Icons.arrow_circle_up_outlined,
                          colors: [AppColors.warning, const Color(0xFFFF8F00)],
                          onPressed: () => _showWithdrawSheet(context),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 24),
                  const _DepositList(),
                  const _WithdrawalList(),
                  const SizedBox(height: 24),
                  const Text(
                    'TRANSACTION HISTORY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  ..._buildMockTransactions(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMockTransactions(BuildContext context) {
    final transactions = [
      _TransactionItem(
        type: 'bonus',
        description: 'Welcome Bonus',
        amount: 1000,
        currency: 'coins',
        isCredit: true,
        date: 'Today',
      ),
    ];

    return transactions
        .asMap()
        .entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e.value,
            ).animate().fadeIn(delay: (400 + e.key * 80).ms, duration: 400.ms))
        .toList();
  }

  void _showDepositSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _DepositSheet(),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _WithdrawSheet(),
    );
  }
}

class _WalletBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final w = wallet.valueOrNull;
    return GlassContainer(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.2),
          AppColors.primary.withValues(alpha: 0.1),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            w?.formattedCash ?? '₱0.00',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniBalance(
                  label: 'Coins',
                  value: w?.formattedCoins ?? '—',
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.coinColor,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.glassBorder),
              Expanded(
                child: _MiniBalance(
                  label: 'Cash',
                  value: w?.formattedCash ?? '₱0.00',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.cashColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBalance extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniBalance({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String type;
  final String description;
  final int amount;
  final String currency;
  final bool isCredit;
  final String date;

  const _TransactionItem({
    required this.type,
    required this.description,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${currency == 'cash' ? '₱' : ''}$amount',
            style: TextStyle(
              color: isCredit ? AppColors.success : AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// The admin's GCash number players send their top-up to.
const String kAdminGcashNumber = '09958947758';

class _DepositSheet extends ConsumerStatefulWidget {
  const _DepositSheet();

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final refNum = _ref.text.trim();
    if (amount < 20) {
      setState(() => _error = 'Minimum deposit is 20.');
      return;
    }
    if (refNum.length < 4) {
      setState(() => _error = 'Enter the GCash reference number.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final user = ref.read(authControllerProvider).valueOrNull;
      await api.post(ApiEndpoints.walletDeposit, data: {
        'amount': amount,
        'gcashRef': refNum,
        'displayName': user?.displayName ?? 'Player',
      });
      ref.invalidate(depositsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deposit request sent — coins are added once the admin '
              'confirms your GCash payment'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      var msg = e.toString();
      try {
        // ignore: avoid_dynamic_calls
        final data = (e as dynamic).response?.data;
        if (data is Map && data['message'] != null) msg = '${data['message']}';
      } catch (_) {}
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Deposit via GCash',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Step-by-step instructions + the GCash number to send to.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Send your GCash to:',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(kAdminGcashNumber,
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: AppColors.success),
                      tooltip: 'Copy number',
                      onPressed: () {
                        Clipboard.setData(
                            const ClipboardData(text: kAdminGcashNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Number copied')),
                        );
                      },
                    ),
                  ],
                ),
                const Text(
                  '2. Enter the amount + GCash reference number below.\n'
                  '3. We verify the payment and credit your coins.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(
              labelText: 'Amount sent',
              prefixText: '🪙 ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ref,
            decoration: const InputDecoration(
              labelText: 'GCash Reference Number',
              hintText: 'e.g. 1234567890123',
            ),
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: _submitting ? 'Submitting…' : 'Submit Deposit Request',
              colors: [AppColors.success, const Color(0xFF00C853)],
              onPressed: _submitting ? null : _submit,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Coins are credited after the admin confirms the payment',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet();

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amount = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final number = _number.text.trim();
    final name = _name.text.trim();
    if (amount < 100) {
      setState(() => _error = 'Minimum withdrawal is 100 coins.');
      return;
    }
    if (number.isEmpty || name.isEmpty) {
      setState(() => _error = 'GCash number and name are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final user = ref.read(authControllerProvider).valueOrNull;
      await api.post(ApiEndpoints.walletWithdraw, data: {
        'amount': amount,
        'gcashNumber': number,
        'gcashName': name,
        'displayName': user?.displayName ?? 'Player',
      });
      ref.invalidate(walletProvider);
      ref.invalidate(withdrawalsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal request submitted — pending admin approval'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      var msg = e.toString();
      // Dio errors surface the server message under response.data.message.
      try {
        // ignore: avoid_dynamic_calls
        final data = (e as dynamic).response?.data;
        if (data is Map && data['message'] != null) msg = '${data['message']}';
      } catch (_) {}
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(walletProvider).valueOrNull;
    final withdrawable = w?.withdrawable ?? 0;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Withdraw to GCash',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Withdrawable: 🪙$withdrawable  (the free bonus must be wagered & won first)',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'GCash Account Name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            decoration: const InputDecoration(
              labelText: 'GCash Number (where to send)',
              prefixText: '+63 ',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(
              labelText: 'Amount (coins)',
              prefixText: '🪙 ',
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          Builder(builder: (_) {
            final amt = int.tryParse(_amount.text.trim()) ?? 0;
            final fee = amt ~/ 100; // 5 per 500 ≈ 1%
            if (amt <= 0) return const SizedBox(height: 8);
            Widget row(String l, String r, {Color? c, bool bold = false}) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l,
                          style: TextStyle(
                              color: c ?? AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight:
                                  bold ? FontWeight.w700 : FontWeight.w400)),
                      Text(r,
                          style: TextStyle(
                              color: c ?? AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight:
                                  bold ? FontWeight.w700 : FontWeight.w600)),
                    ],
                  ),
                );
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  row('Amount requested', '🪙$amt'),
                  row('Processing fee (1% · 5 per 500)', '−🪙$fee',
                      c: AppColors.warning),
                  const Divider(height: 12, color: AppColors.glassBorder),
                  row('You receive on GCash', '🪙${amt - fee}',
                      c: AppColors.success, bold: true),
                ],
              ),
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: _submitting ? 'Submitting…' : 'Submit Withdrawal Request',
              colors: [AppColors.warning, const Color(0xFFFF8F00)],
              onPressed: _submitting ? null : _submit,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Admin reviews & sends to your GCash within 24-48 hours',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the player's withdrawal requests with live status + progress.
/// The player's deposit (top-up) requests with live status.
class _DepositList extends ConsumerWidget {
  const _DepositList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(depositsProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'DEPOSIT REQUESTS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh,
                  size: 18, color: AppColors.textSecondary),
              onPressed: () => ref.invalidate(depositsProvider),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DepositCard(d),
            )),
        const SizedBox(height: 12),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _DepositCard extends StatelessWidget {
  final DepositModel d;
  const _DepositCard(this.d);

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (d.status) {
      'approved' => (AppColors.success, 'Coins added', Icons.check_circle),
      'rejected' => (AppColors.error, 'Rejected', Icons.cancel),
      _ => (AppColors.warning, 'Verifying payment', Icons.hourglass_top),
    };
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🪙${d.amount}  ·  Ref ${d.gcashRef}',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(_fmtDate(d.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (d.status == 'rejected' && (d.note?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text('Reason: ${d.note}',
                style: const TextStyle(color: AppColors.error, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _WithdrawalList extends ConsumerWidget {
  const _WithdrawalList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(withdrawalsProvider);
    final items = async.valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'WITHDRAWAL REQUESTS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18,
                  color: AppColors.textSecondary),
              onPressed: () => ref.invalidate(withdrawalsProvider),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WithdrawalCard(w),
            )),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _WithdrawalCard extends StatelessWidget {
  final WithdrawalModel w;
  const _WithdrawalCard(this.w);

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (w.status) {
      'approved' => (AppColors.success, 'Sent to GCash', Icons.check_circle),
      'rejected' => (AppColors.error, 'Failed / Rejected', Icons.cancel),
      _ => (AppColors.warning, 'Pending admin approval', Icons.hourglass_top),
    };
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🪙${w.net} → ${w.gcashNumber}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Requested 🪙${w.amount} − fee 🪙${w.fee} = 🪙${w.net}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                    Text(
                      '${w.gcashName} · ${_fmtDate(w.createdAt)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (w.status == 'rejected' && (w.note?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${w.note} (coins refunded)',
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
