import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/chat_list_screen.dart';

// ─── HELPER FUNCTIONS ────────────────────────────────────────────────────────
void _handleWhatsApp(BuildContext context, String? phone, String text) async {
  if (phone == null || phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Номер телефона не указан')));
    return;
  }
  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
  String targetPhone = cleanPhone;
  if (targetPhone.startsWith('0') && targetPhone.length >= 9) {
    targetPhone = '996${targetPhone.substring(1)}';
  } else if (!targetPhone.startsWith('996') && targetPhone.length >= 9) {
    targetPhone = '996$targetPhone';
  }
  final url = Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(text)}');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть WhatsApp')));
    }
  }
}

void _handleSendPush(BuildContext context, String clientId, String text) async {
  try {
    await ApiService().sendPush(clientId, 'Уведомление', text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Push-уведомление отправлено'), backgroundColor: Colors.green));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red));
    }
  }
}

// ─── Цветовая палитра ────────────────────────────────────────────────────────
class _C {
  static const gold = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const accent = Color(0xFF2563EB);
  static const accentLt = Color(0xFF3B82F6);
}

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  final _api = ApiService();

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<dynamic>> _overdueFuture;
  late Future<List<dynamic>> _approvalsFuture;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _statsFuture = _api.getDashboardStats();
    _overdueFuture = _api.getOverdueLoans();
    _approvalsFuture = _api.getApprovals();
    _doSearch(); // Загружаем последних клиентов при старте
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Timer? _searchDebounce;

  Future<void> _doSearch() async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final query = _searchCtrl.text.trim();
      final res = await _api.searchClients(query);
      if (mounted) setState(() => _searchResults = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: _C.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    // ВАЖНО: Добавляем чтение locale, чтобы виджет перестраивался при смене языка
    final currentLocale = context.locale;

    final auth = context.read<AuthService>();
    final fmt = NumberFormat(
        '#,##0.00', currentLocale.languageCode == 'ru' ? 'ru_RU' : 'en_US');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: pal.bg,
        appBar: _buildAppBar(auth),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _buildHomeTab(fmt),
              _buildSearchTab(fmt),
              _buildApprovalsTab(fmt),
              _buildOverdueTab(fmt),
              const ChatListScreen(isStaff: true),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(AuthService auth) {
    final pal = AppPalette.of(context);
    return AppBar(
      backgroundColor: pal.bg,
      elevation: 0,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.accent, _C.accentLt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'staff.dashboard'.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pal.textPri,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  auth.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.textSec, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Тема',
          icon: Icon(
            context.watch<ThemeController>().isLight
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: pal.textSec,
            size: 22,
          ),
          onPressed: () => context.read<ThemeController>().toggle(),
        ),
        _LangButton(),
        Container(
          margin: const EdgeInsets.only(right: 12, left: 4),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: IconButton(
            icon: Icon(Icons.logout_rounded, color: pal.textSec, size: 20),
            onPressed: () async {
              final auth = context.read<AuthService>();
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ),
      ],
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final pal = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'staff.home'.tr(),
                  index: 0,
                  current: _tabIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'staff.clients'.tr(),
                  index: 1,
                  current: _tabIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.fact_check_rounded,
                  label: 'staff.approvals'.tr(),
                  index: 2,
                  current: _tabIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'staff.overdue'.tr(),
                  index: 3,
                  current: _tabIndex,
                  onTap: _setTab),
              _NavItem(
                  icon: Icons.chat_rounded,
                  label: 'Чат',
                  index: 4,
                  current: _tabIndex,
                  onTap: _setTab),
            ],
          ),
        ),
      ),
    );
  }

  void _setTab(int i) => setState(() => _tabIndex = i);

  // ─── HOME TAB ──────────────────────────────────────────────────────────────
  Widget _buildHomeTab(NumberFormat fmt) {
    final pal = AppPalette.of(context);
    return RefreshIndicator(
      color: _C.accentLt,
      backgroundColor: pal.card,
      onRefresh: () async =>
          setState(() => _statsFuture = _api.getDashboardStats()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Приветственный баннер
          _WelcomeBanner(),
          const SizedBox(height: 24),

          // Счета
          _SectionHeader(title: 'staff.accounts'.tr()),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _CardSkeleton(height: 100);
              }
              if (snap.hasError) {
                return _ErrorTile(message: snap.error.toString());
              }
              final data = snap.data ?? {'cash_balance': 0, 'bank_balance': 0};
              return Row(
                children: [
                  Expanded(
                      child: _BalanceCard(
                    label: 'Касса',
                    code: '10001',
                    amount: fmt.format(data['cash_balance']),
                    icon: Icons.account_balance_wallet_rounded,
                    color: _C.green,
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _BalanceCard(
                    label: 'Кор. счёт',
                    code: '10101',
                    amount: fmt.format(data['bank_balance']),
                    icon: Icons.account_balance_rounded,
                    color: _C.gold,
                  )),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'staff.actions'.tr()),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _ActionCard(
                icon: Icons.people_alt_rounded,
                label: 'staff.clients'.tr(),
                color: _C.accentLt,
                onTap: () => _setTab(1),
              ),
              _ActionCard(
                icon: Icons.fact_check_rounded,
                label: 'staff.approvals'.tr(),
                color: _C.orange,
                onTap: () => _setTab(2),
              ),
              _ActionCard(
                icon: Icons.warning_amber_rounded,
                label: 'staff.overdue'.tr(),
                color: _C.red,
                onTap: () => _setTab(3),
              ),
              _ActionCard(
                icon: Icons.add_card_rounded,
                label: 'Новый займ',
                color: _C.green,
                onTap: () => context.push('/staff/issue-loan'),
              ),
              _ActionCard(
                icon: Icons.person_add_rounded,
                label: 'Новый клиент',
                color: _C.accent,
                onTap: () => context.push('/staff/register-client'),
              ),
              _ActionCard(
                icon: Icons.assignment_rounded,
                label: 'Журнал',
                color: _C.accent,
                onTap: () => context.push('/staff/journal'),
              ),
              _ActionCard(
                icon: Icons.map_rounded,
                label: 'Карта визитов',
                color: _C.gold,
                onTap: () => context.push('/staff/visits'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SEARCH TAB ────────────────────────────────────────────────────────────
  Widget _buildSearchTab(NumberFormat fmt) {
    final pal = AppPalette.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: pal.bg,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: pal.border),
                  ),
                  child: TextFormField(
                    key: const Key('search_field_fixed'),
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: pal.textPri,
                      fontSize: 15,
                      fontFamily: 'sans-serif', // Системный шрифт
                    ),
                    decoration: InputDecoration(
                      hintText: 'staff.search_hint'.tr(),
                      hintStyle: TextStyle(color: pal.textHint, fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: pal.textSec, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) {
                      _searchDebounce?.cancel();
                      if (v.trim().isEmpty) {
                        setState(() => _searchResults = []);
                        return;
                      }
                      if (v.trim().length > 1) {
                        _searchDebounce =
                            Timer(const Duration(milliseconds: 500), () {
                          _doSearch();
                        });
                      }
                    },
                    onFieldSubmitted: (_) => _doSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Создание клиента в разработке'),
                      behavior: SnackBarBehavior.floating),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_C.accent, _C.accentLt]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        if (_isSearching)
          LinearProgressIndicator(
            backgroundColor: pal.surface,
            color: _C.accentLt,
            minHeight: 2,
          ),
        Expanded(
          child: _searchResults.isEmpty
              ? _EmptyState(
                  icon: Icons.manage_search_rounded,
                  message: _searchCtrl.text.isEmpty
                      ? 'Список клиентов'
                      : 'Ничего не найдено',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) => _ClientCard(
                    client: _searchResults[i],
                    fmt: fmt,
                    onTap: () => context.push(
                        '/staff/client/${_searchResults[i]['client_id']}'),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── APPROVALS TAB ────────────────────────────────────────────────────────
  Widget _buildApprovalsTab(NumberFormat fmt) {
    final pal = AppPalette.of(context);
    return FutureBuilder<List<dynamic>>(
      future: _approvalsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.accentLt));
        }
        if (snap.hasError) return _ErrorTile(message: snap.error.toString());

        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _EmptyState(
              icon: Icons.fact_check_rounded,
              message: 'staff.no_approvals'.tr());
        }

        return RefreshIndicator(
          color: _C.accentLt,
          backgroundColor: pal.card,
          onRefresh: () async =>
              setState(() => _approvalsFuture = _api.getApprovals()),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return _ApprovalCard(
                item: item,
                fmt: fmt,
                onTap: () => context.push('/staff/client/${item['client_id']}'),
              );
            },
          ),
        );
      },
    );
  }

  // ─── OVERDUE TAB ──────────────────────────────────────────────────────────
  Widget _buildOverdueTab(NumberFormat fmt) {
    final pal = AppPalette.of(context);
    return FutureBuilder<List<dynamic>>(
      future: _overdueFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.accentLt));
        }
        if (snap.hasError) return _ErrorTile(message: snap.error.toString());

        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _EmptyState(
              icon: Icons.check_circle_rounded,
              message: 'staff.no_overdue'.tr());
        }

        return RefreshIndicator(
          color: _C.accentLt,
          backgroundColor: pal.card,
          onRefresh: () async =>
              setState(() => _overdueFuture = _api.getOverdueLoans()),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return _OverdueCard(
                item: item,
                fmt: fmt,
                onTap: () => context.push('/staff/client/${item['client_id']}'),
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ═══════════════════════════════════════════════════════════════════════════════

class _LangButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: PopupMenuButton<Locale>(
        icon: Icon(Icons.language_rounded, color: pal.textSec, size: 20),
        color: pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: pal.border),
        ),
        onSelected: (locale) => EasyLocalization.of(context)!.setLocale(locale),
        itemBuilder: (_) => [
          _langItem('RU', 'Русский', const Locale('ru'), pal),
          _langItem('KY', 'Кыргызча', const Locale('ky'), pal),
          _langItem('EN', 'English', const Locale('en'), pal),
        ],
      ),
    );
  }

  PopupMenuItem<Locale> _langItem(
      String code, String label, Locale locale, AppPalette pal) {
    return PopupMenuItem(
      value: locale,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 22,
            decoration: BoxDecoration(
              color: pal.border,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(code,
                style: TextStyle(
                    color: pal.textPri,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: pal.textPri)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _C.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? _C.accentLt : pal.textSec, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? _C.accentLt : pal.textSec,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D3A6E), Color(0xFF1A56DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _C.accent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('staff.welcome'.tr(),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 6),
                Text('staff.question'.tr(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Row(
      children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                color: _C.accentLt, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: pal.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label, code, amount;
  final IconData icon;
  final Color color;
  const _BalanceCard(
      {required this.label,
      required this.code,
      required this.amount,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$label ($code)',
              style: TextStyle(color: pal.textSec, fontSize: 11)),
          const SizedBox(height: 4),
          Text('$amount сом',
              style: TextStyle(
                  color: pal.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    color: pal.textPri,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final dynamic client;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _ClientCard(
      {required this.client, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final loans = client['active_loans_count'] ?? 0;
    final balance =
        double.tryParse(client['total_balance']?.toString() ?? '0') ?? 0;
    final phone = client['phone_main'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                (client['full_name'] ?? '?').toString().substring(0, 1),
                style: const TextStyle(
                    color: _C.accentLt,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client['full_name'] ?? 'Без имени',
                      style: TextStyle(
                          color: pal.textPri,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(phone,
                      style: TextStyle(color: pal.textSec, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(label: '$loans кр.', color: _C.accentLt),
                      const SizedBox(width: 8),
                      Text('${fmt.format(balance)} сом',
                          style: const TextStyle(
                              color: _C.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_rounded, color: _C.accentLt, size: 22),
                  onPressed: () => _handleSendPush(context, client['client_id']?.toString() ?? '', 'Уважаемый клиент ${client['full_name']}, просим вас связаться с нами.'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                  onPressed: () => _handleWhatsApp(context, phone, 'Здравствуйте, ${client['full_name']}.'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: pal.textHint, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final dynamic item;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _ApprovalCard(
      {required this.item, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final amount = double.tryParse(item['loan_amount']?.toString() ?? '0') ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.orange.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _C.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.hourglass_top_rounded,
                  color: _C.orange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['full_name'] ?? '',
                      style: TextStyle(
                          color: pal.textPri,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                      '${item['purpose'] ?? 'Кредит'} · ${fmt.format(amount)} сом',
                      style: const TextStyle(color: _C.orange, fontSize: 12)),
                ],
              ),
            ),
            _Chip(label: item['status'] ?? 'Заявка', color: _C.orange),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final dynamic item;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _OverdueCard(
      {required this.item, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final debt =
        double.tryParse(item['principal_balance']?.toString() ?? '0') ?? 0;
    final days = item['days_overdue'] ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.red.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.warning_rounded, color: _C.red, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['full_name'] ?? '',
                      style: TextStyle(
                          color: pal.textPri,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${fmt.format(debt)} сом · $days дн.',
                      style: const TextStyle(color: _C.red, fontSize: 12)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_rounded, color: _C.red, size: 22),
                  onPressed: () => _handleSendPush(context, item['client_id']?.toString() ?? '', 'Напоминаем о просрочке по договору. Сумма к погашению: ${fmt.format(debt)} сом. Просим погасить задолженность.'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                  onPressed: () => _handleWhatsApp(context, item['phone_main']?.toString(), 'Здравствуйте, ${item['full_name']}. Напоминаем о просрочке по договору. Сумма к погашению: ${fmt.format(debt)} сом. Просим срочно произвести оплату.'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: pal.textHint, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final double height;
  const _CardSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _C.red, size: 40),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(color: pal.textSec),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: pal.textHint, size: 48),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: pal.textSec, fontSize: 14)),
        ],
      ),
    );
  }
}
