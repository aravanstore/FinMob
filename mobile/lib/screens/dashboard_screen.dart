import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/loan.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/loan_calculator.dart';
import 'shared/chat_list_screen.dart';
import '../services/push_notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  late Future<List<Loan>> _loansFuture;
  late Future<Map<String, dynamic>> _sharesFuture;
  int _currentIndex = 0;

  Timer? _chatPollingTimer;

  @override
  void initState() {
    super.initState();
    _loansFuture = _loadLoans();
    _sharesFuture = _api.getSharesSummary();
    
    // Проверка объявлений только один раз при загрузке
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAnnouncements();
      _pollChatUnread();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pollChatUnread() async {
    try {
      final auth = context.read<AuthService>();
      final contacts = await _api.getChatContacts(isStaff: auth.role == 'staff');
      int total = 0;
      for (var c in contacts) {
        total += int.tryParse(c['unread_count']?.toString() ?? '0') ?? 0;
      }
      PushNotificationService.chatUnreadCount.value = total;
    } catch (e) {
      debugPrint('Poll chat unread error: $e');
    }
  }

  Future<void> _checkAnnouncements() async {
    try {
      final announcement = await _api.getActiveAnnouncement();
      if (announcement != null && announcement['id'] != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final lastId = prefs.getInt('last_announcement_id');
        
        if (lastId != announcement['id']) {
          _showAnnouncementDialog(announcement);
        }
      }
    } catch (e) {
      debugPrint('Check announcements error: $e');
    }
  }

  void _showAnnouncementDialog(dynamic data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.amber, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['title'] ?? 'Объявление',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white12),
            const SizedBox(height: 10),
            Text(
              data['message'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('last_announcement_id', data['id']);
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'Понятно',
              style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Loan>> _loadLoans() async {
    final data = await _api.getLoans();
    return data.map((j) => Loan.fromJson(j as Map<String, dynamic>)).toList();
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final pal = AppPalette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: _currentIndex == 0 ? _buildHomeAppBar(auth, pal) : null,
      body: FutureBuilder<List<Loan>>(
        future: _loansFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snap.hasError) return _buildErrorView(pal);

          final loans = snap.data!;
          return FutureBuilder<Map<String, dynamic>>(
            future: _sharesFuture,
            builder: (ctx, shareSnap) {
              final shares = shareSnap.data ?? {};
              return IndexedStack(
                index: _currentIndex,
                children: [
                  _HomeTab(loans: loans, shares: shares, fmt: fmt, onTabChange: (i) => setState(() => _currentIndex = i)),
                  _LoansTab(loans: loans, fmt: fmt),
                  _SharesTab(shares: shares, fmt: fmt),
                  const ChatListScreen(isStaff: false),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 3) {
              // Вкладка чата
              PushNotificationService.chatUnreadCount.value = 0;
            }
          },
          backgroundColor: pal.card,
          selectedItemColor: const Color(0xFF1A56DB),
          unselectedItemColor: pal.textSec.withValues(alpha: 0.5),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Главная'),
            const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Кредиты'),
            const BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'Паи'),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<int>(
                valueListenable: PushNotificationService.chatUnreadCount,
                builder: (context, count, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_rounded),
                      if (count > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Чат',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar(AuthService auth, AppPalette pal) {
    return AppBar(
      backgroundColor: pal.bg,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Здравствуйте,', style: TextStyle(color: pal.textSec, fontSize: 14)),
          Text(auth.fullName.split(' ')[0], style: TextStyle(color: pal.textPri, fontWeight: FontWeight.bold, fontSize: 22)),
        ],
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: PushNotificationService.unreadCount,
          builder: (context, count, _) {
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: pal.textSec),
                  onPressed: () => context.push('/notifications'),
                ),
                if (count > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            );
          }
        ),
        IconButton(
          icon: Icon(Icons.logout_rounded, color: pal.textSec),
          onPressed: () async {
            await context.read<AuthService>().logout();
            if (mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _buildErrorView(AppPalette pal) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white30, size: 64),
          const SizedBox(height: 16),
          Text('client.no_connection'.tr(), style: TextStyle(color: pal.textSec)),
          TextButton(onPressed: () => setState(() { _loansFuture = _loadLoans(); _sharesFuture = _api.getSharesSummary(); }), child: Text('client.retry'.tr())),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final List<Loan> loans;
  final Map<String, dynamic> shares;
  final NumberFormat fmt;
  final Function(int) onTabChange;

  const _HomeTab({required this.loans, required this.shares, required this.fmt, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final activeLoans = loans.where((l) => l.isActive).toList();
    final totalDebt = activeLoans.fold(0.0, (sum, l) => sum + l.totalDebt);

    return RefreshIndicator(
      onRefresh: () async { /* Parent handles it */ },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Total Debt Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF1A56DB).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Общая задолженность', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                    const Icon(Icons.shield_rounded, color: Colors.white54, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${fmt.format(totalDebt)} сом', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _quickAction(context, Icons.qr_code_scanner, 'Оплатить', () => context.go('/payments')),
                    const SizedBox(width: 12),
                    _quickAction(context, Icons.calculate_outlined, 'Расчёт', () => LoanCalculator.show(context)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          
          // Services Section
          _sectionTitle(pal, 'Сервисы'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _serviceItem(context, Icons.chat_rounded, 'Поддержка', () => onTabChange(3)),
              _serviceItem(context, Icons.history_rounded, 'История', () => onTabChange(2)),
              _serviceItem(context, Icons.description_outlined, 'Справки', () {}),
              _serviceItem(context, Icons.settings_outlined, 'Настройки', () {}),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Active Loan Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(pal, 'Активные кредиты'),
              TextButton(onPressed: () => onTabChange(1), child: const Text('Все')),
            ],
          ),
          if (activeLoans.isEmpty)
             Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Нет активных кредитов', style: TextStyle(color: pal.textSec))))
          else
            _LoanCard(loan: activeLoans[0], fmt: fmt),
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final pal = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.border),
            ),
            child: Icon(icon, color: const Color(0xFF1A56DB), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: pal.textSec, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppPalette pal, String title) {
    return Text(title, style: TextStyle(color: pal.textPri, fontSize: 18, fontWeight: FontWeight.bold));
  }
}

class _LoansTab extends StatelessWidget {
  final List<Loan> loans;
  final NumberFormat fmt;
  const _LoansTab({required this.loans, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(backgroundColor: pal.bg, elevation: 0, title: const Text('Мои кредиты', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: loans.length,
        itemBuilder: (context, i) => _LoanCard(loan: loans[i], fmt: fmt),
      ),
    );
  }
}

class _SharesTab extends StatelessWidget {
  final Map<String, dynamic> shares;
  final NumberFormat fmt;
  const _SharesTab({required this.shares, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(backgroundColor: pal.bg, elevation: 0, title: const Text('Паевые взносы', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SharesCard(shares: _d(shares['share_balance']), dividends: _d(shares['accrued_dividends']), fmt: fmt),
          const SizedBox(height: 24),
          _ContactSection(),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final NumberFormat fmt;
  const _LoanCard({required this.loan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final color = loan.isOverdue
        ? Colors.redAccent
        : loan.isActive
            ? const Color(0xFF1A56DB)
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: pal.accent.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Кредит №${loan.contractNumber}',
                  style: TextStyle(
                      color: pal.textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  loan.isOverdue ? 'Просрочен' : loan.isActive ? 'Активен' : 'Закрыт',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${fmt.format(loan.totalDebt)} сом',
            style: TextStyle(
                color: pal.textPri, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text('Остаток основного долга',
              style: TextStyle(color: pal.textSec.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? pal.bg.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Builder(
              builder: (context) {
                double safe(dynamic v, double fallback) {
                  if (v == null) return fallback;
                  if (v is num) return v.toDouble();
                  return double.tryParse(v.toString()) ?? fallback;
                }
                
                final odCol1 = safe(loan.board?['od_col1_overdue'], 0);
                final odCol2 = safe(loan.board?['od_col2_scheduled'], 0);
                final odCol3 = safe(loan.board?['od_col3_full'], loan.principalBalance);
                
                final intCol1 = safe(loan.board?['int_col1'], loan.overdueInterest);
                final intCol2 = safe(loan.board?['int_col2'], loan.accruedInterest); // fallback
                final intCol3 = safe(loan.board?['int_col3'], loan.accruedInterest);
                
                final penCol1 = safe(loan.board?['pen_col1'], loan.accruedPenalty);
                final penCol2 = safe(loan.board?['pen_col2'], loan.accruedPenalty);
                final penCol3 = safe(loan.board?['pen_col3'], loan.accruedPenalty);
                
                final totalCol1 = safe(loan.board?['total_col1'], loan.totalOverdue);
                final totalCol2 = safe(loan.board?['total_col2'], loan.totalOverdue); // fallback
                final totalCol3 = safe(loan.board?['total_col3'], loan.fullRepayment);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Информационное табло', style: TextStyle(color: pal.textSec, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: Text('НАИМЕНОВАНИЕ', style: TextStyle(color: pal.textHint, fontSize: 8))),
                        Expanded(flex: 2, child: Text('ПРОСРОЧКА', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 8))),
                        Expanded(flex: 2, child: Text('К КОНЦУ МЕС.', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 8))),
                        Expanded(flex: 2, child: Text('ПОЛН. ПОГ.', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 8))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTableRow(context, 'ОД', odCol1, odCol2, odCol3),
                    _buildTableRow(context, 'Проценты', intCol1, intCol2, intCol3),
                    _buildTableRow(context, 'Пени', penCol1, penCol2, penCol3),
                    Divider(color: pal.border, height: 16),
                    _buildTableRow(context, 'ИТОГО', totalCol1, totalCol2, totalCol3, isBold: true),
                    const SizedBox(height: 12),
                    _infoRow(context, 'Процентная ставка:', '${loan.interestRate}% годовых'),
                    const SizedBox(height: 6),
                    _infoRow(context, 'Срок кредита:', '${DateFormat('dd.MM.yy').format(loan.issueDate)} — ${DateFormat('dd.MM.yy').format(loan.endDate)}'),
                  ],
                );
              }
            ),
          ),

          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: loan.paidPercent,
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? pal.border.withValues(alpha: 0.6)
                  : Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Выплачено ${(loan.paidPercent * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: pal.textSec.withValues(alpha: 0.75), fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/schedule/${loan.id}'),
                  icon: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
                  label: const Text('График', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/history/${loan.id}'),
                  icon: const Icon(Icons.history, size: 16, color: Colors.white),
                  label: const Text('История', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTableRow(BuildContext context, String label, double v1, double v2, double v3, {bool isBold = false}) {
    final pal = AppPalette.of(context);
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final style = TextStyle(
      color: isBold ? pal.textPri : pal.textSec, 
      fontSize: 11, 
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: style)),
          Expanded(flex: 2, child: Text(fmt.format(v1.round()), textAlign: TextAlign.right, style: style.copyWith(color: v1 > 0 ? Colors.redAccent : style.color))),
          Expanded(flex: 2, child: Text(fmt.format(v2.round()), textAlign: TextAlign.right, style: style.copyWith(color: v2 > 0 ? Colors.blueAccent : style.color))),
          Expanded(flex: 2, child: Text(fmt.format(v3.round()), textAlign: TextAlign.right, style: style.copyWith(color: isBold ? Colors.greenAccent : style.color))),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value,
      {bool isBold = false, Color? color}) {
    final pal = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: pal.textSec, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: color ?? pal.textPri,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }
}

class _SharesCard extends StatelessWidget {
  final double shares;
  final double dividends;
  final NumberFormat fmt;
  const _SharesCard({required this.shares, required this.dividends, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.light
              ? [pal.card, pal.surface]
              : const [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? pal.border : Colors.white10),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: pal.accent.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Паи и Дивиденды',
              style: TextStyle(color: pal.textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statColumn('Мои паи', '${fmt.format(shares)} сом', Colors.blueAccent)),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(child: _statColumn('Дивиденды', '${fmt.format(dividends)} сом', Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/shares-history'),
              icon: const Icon(Icons.history, size: 16, color: Colors.white),
              label: const Text('История операций', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? pal.card
            : const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? pal.border : Colors.white10),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: pal.accent.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pal.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.headset_mic_rounded, color: pal.accentLt, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Появились вопросы?', style: TextStyle(color: pal.textPri, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Свяжитесь с нами или оставьте заявку', style: TextStyle(color: pal.textSec.withValues(alpha: 0.8), fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/inquiry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Связаться', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _CalculatorSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: pal.accent.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calculate, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Кредитный калькулятор', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Рассчитайте новый займ', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => LoanCalculator.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Открыть', style: TextStyle(color: Color(0xFF1A56DB), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
