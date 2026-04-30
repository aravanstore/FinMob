import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

  // Overdue state
  late Future<List<dynamic>> _overdueFuture;

  @override
  void initState() {
    super.initState();
    _overdueFuture = _api.getOverdueLoans();
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) return;
    
    setState(() => _isSearching = true);
    try {
      final res = await _api.searchClients(q);
      setState(() => _searchResults = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка поиска: $e')));
    } finally {
      setState(() => _isSearching = false);
    }
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
            const Text('Панель сотрудника', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(auth.fullName, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
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
          _buildSearchTab(fmt),
          _buildApprovalsTab(),
          _buildOverdueTab(fmt),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF1A56DB),
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Поиск'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: 'Одобрения'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Просрочка'),
        ],
      ),
    );
  }

  Widget _buildSearchTab(NumberFormat fmt) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Имя, телефон или ИНН...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF1A56DB)),
                onPressed: _doSearch,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _doSearch(),
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

  Widget _buildApprovalsTab() {
    return const Center(child: Text('Раздел одобрений в разработке', style: TextStyle(color: Colors.white38)));
  }

  Widget _buildOverdueTab(NumberFormat fmt) {
    return FutureBuilder<List<dynamic>>(
      future: _overdueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.white38)));
        
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Просрочек не найдено', style: TextStyle(color: Colors.white38)));

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
