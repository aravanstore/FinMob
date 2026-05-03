import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/loan.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  late Future<List<Loan>> _loansFuture;
  late Future<Map<String, dynamic>> _sharesFuture;

  @override
  void initState() {
    super.initState();
    _loansFuture = _loadLoans();
    _sharesFuture = _api.getSharesSummary();
    
    // Проверка объявлений только один раз при загрузке
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAnnouncements();
    });
  }

  Future<void> _checkAnnouncements() async {
    try {
      final announcement = await _api.getActiveAnnouncement();
      if (announcement != null && mounted) {
        _showAnnouncementDialog(announcement);
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
            onPressed: () => Navigator.pop(context),
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
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final pal = AppPalette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('client.my_loans'.tr(),
                style: TextStyle(
                    color: pal.textPri,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text(auth.phone,
                style: TextStyle(color: pal.textSec.withValues(alpha: 0.75), fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: Icon(Icons.language, color: pal.textSec),
            onSelected: (locale) {
              EasyLocalization.of(context)!.setLocale(locale);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: Locale('ru'), child: Text('Русский')),
              const PopupMenuItem(value: Locale('ky'), child: Text('Кыргызча')),
              const PopupMenuItem(value: Locale('en'), child: Text('English')),
            ],
          ),
          IconButton(
            tooltip: 'Тема',
            icon: Icon(
              context.watch<ThemeController>().isLight
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: pal.textSec,
            ),
            onPressed: () => context.read<ThemeController>().toggle(),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: pal.textSec),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Loan>>(
        future: _loansFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white30, size: 64),
                  const SizedBox(height: 16),
                  Text('client.no_connection'.tr(),
                      style: TextStyle(color: pal.textSec)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => setState(() {
                            _loansFuture = _loadLoans();
                            _sharesFuture = _api.getSharesSummary();
                          }),
                      child: Text('client.retry'.tr())),
                ],
              ),
            );
          }

          final loans = snap.data!;

          return RefreshIndicator(
            onRefresh: () async => setState(() {
              _loansFuture = _loadLoans();
              _sharesFuture = _api.getSharesSummary();
            }),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _sharesFuture,
                  builder: (context, shareSnap) {
                    if (shareSnap.hasData) {
                      final s = shareSnap.data!;
                      return Column(
                        children: [
                          _SharesCard(
                            shares:    _d(s['share_balance']),
                            dividends: _d(s['accrued_dividends']),
                            fmt: fmt,
                          ),
                          const SizedBox(height: 16),
                          _ContactSection(),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 20),
                Text('client.active_loans'.tr(),
                    style: TextStyle(
                        color: pal.textPri,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (loans.isEmpty)
                  Center(
                      child: Text('client.no_loans'.tr(),
                          style: TextStyle(color: pal.textSec.withValues(alpha: 0.75))))
                else
                  ...loans.map((l) => _LoanCard(loan: l, fmt: fmt)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/payments'),
        backgroundColor: const Color(0xFF1A56DB),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Оплатить', style: TextStyle(color: Colors.white)),
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
