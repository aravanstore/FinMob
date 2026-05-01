import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _tabIndex = 0;
  final _api = ApiService();
  
  // Search state
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Dashboard Stats state
  late Future<Map<String, dynamic>> _statsFuture;

  // Overdue state
  late Future<List<dynamic>> _overdueFuture;



  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    
    setState(() => _isSearching = true);
    try {
      final res = await _api.searchClients(q);
      setState(() => _searchResults = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _overdueFuture = _api.getOverdueLoans();
    _approvalsFuture = _api.getApprovals();
    _statsFuture = _api.getDashboardStats();
    _doSearch(); // Загружаем список клиентов по умолчанию
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('staff.dashboard'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(auth.fullName, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white54),
            onSelected: (locale) {
              print("SWITCHING LOCALE TO: ${locale.languageCode}");
              EasyLocalization.of(context)!.setLocale(locale);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: Locale('ru'), child: Text('Русский')),
              const PopupMenuItem(value: Locale('ky'), child: Text('Кыргызча')),
              const PopupMenuItem(value: Locale('en'), child: Text('English')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(fmt),
          _buildSearchTab(fmt),
          _buildApprovalsTab(fmt),
          _buildOverdueTab(fmt),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF1A56DB),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'staff.home'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: 'staff.clients'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.fact_check), label: 'staff.approvals'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.warning_amber_rounded), label: 'staff.overdue'.tr()),
        ],
      ),
    );
  }

  Widget _buildHomeTab(NumberFormat fmt) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _statsFuture = _api.getDashboardStats();
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('staff.welcome'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('staff.question'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text('staff.accounts'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              final data = snapshot.data ?? {'cash_balance': 0, 'bank_balance': 0};
              return Row(
                children: [
                  Expanded(
                    child: _balanceCard(
                      'Касса (10001)', 
                      '${fmt.format(data['cash_balance'])} сом', 
                      Icons.account_balance_wallet, 
                      Colors.green
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _balanceCard(
                      'Кор счет (10101)', 
                      '${fmt.format(data['bank_balance'])} сом', 
                      Icons.account_balance, 
                      Colors.orange
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          Text('staff.actions'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _homeButton(Icons.people, 'staff.clients'.tr(), Colors.blue, () => setState(() => _tabIndex = 1)),
            _homeButton(Icons.fact_check, 'staff.approvals'.tr(), Colors.orange, () => setState(() => _tabIndex = 2)),
            _homeButton(Icons.warning_amber_rounded, 'staff.overdue'.tr(), Colors.redAccent, () => setState(() => _tabIndex = 3)),
            _homeButton(Icons.add_card, 'Новый займ', Colors.green, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')));
            }),
          ],
        ),
      ],
    ),
    );
  }

  Widget _balanceCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _homeButton(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(NumberFormat fmt) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'staff.search_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    if (v.isEmpty || v.length > 1) _doSearch();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Создание клиента в разработке')));
                  },
                ),
              ),
            ],
          ),
        ),
        if (_isSearching)
          const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF1A56DB)),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(child: Text(_searchCtrl.text.isEmpty ? 'Введите данные для поиска' : 'Ничего не найдено', style: const TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) {
                    final c = _searchResults[i];
                    return _clientCard(c, fmt);
                  },
                ),
        ),
      ],
    );
  }

  Widget _clientCard(dynamic c, NumberFormat fmt) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(c['full_name'] ?? 'Без имени', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(c['phone_main'] ?? '-', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            Row(
              children: [
                _badge('${c['active_loans_count']} кр.', Colors.blue),
                const SizedBox(width: 8),
                Text('${fmt.format(double.parse(c['total_balance'].toString()))} сом', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () => context.push('/staff/client/${c['client_id']}'),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // Approvals state
  late Future<List<dynamic>> _approvalsFuture;



  Widget _buildApprovalsTab(NumberFormat fmt) {
    return FutureBuilder<List<dynamic>>(
      future: _approvalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.white38)));
        
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(child: Text('staff.no_approvals'.tr(), style: const TextStyle(color: Colors.white38)));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _approvalsFuture = _api.getApprovals()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(item['full_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${item['purpose'] ?? 'Кредит'} • ${fmt.format(double.parse(item['loan_amount'].toString()))} сом', style: const TextStyle(color: Colors.orangeAccent)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(item['status'] ?? 'Заявка', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => context.push('/staff/client/${item['client_id']}'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOverdueTab(NumberFormat fmt) {
    return FutureBuilder<List<dynamic>>(
      future: _overdueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.white38)));
        
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(child: Text('staff.no_overdue'.tr(), style: const TextStyle(color: Colors.white38)));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _overdueFuture = _api.getOverdueLoans()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(item['full_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Дней: ${item['days_overdue']} | Долг: ${fmt.format(double.parse(item['principal_balance'].toString()))} сом', style: const TextStyle(color: Colors.redAccent)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  onTap: () => context.push('/staff/client/${item['client_id']}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
