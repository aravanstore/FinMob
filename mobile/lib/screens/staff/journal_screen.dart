import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  String? _startDate;
  String? _endDate;
  final _searchController = TextEditingController();
  final _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getJournal(
        startDate: _startDate,
        endDate: _endDate,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        accountCode: _accountController.text.isNotEmpty ? _accountController.text : null,
      );
      setState(() {
        _transactions = data['transactions'] ?? [];
        _startDate = data['startDate'];
        _endDate = data['endDate'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('staff.error_loading'.tr())),
        );
      }
    }
  }

  Future<void> _selectDates() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(
              start: DateTime.parse(_startDate!),
              end: DateTime.parse(_endDate!),
            )
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1A56DB),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start.toISO().slice(0, 10);
        _endDate = picked.end.toISO().slice(0, 10);
      });
      _loadJournal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.go('/staff'),
        ),
        title: const Text(
          'Журнал операций',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: _selectDates,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadJournal(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ФИО, №, описание',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadJournal();
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadJournal,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Dates Badge
          if (_startDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Период: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(_startDate!))} — ${DateFormat('dd.MM.yyyy').format(DateTime.parse(_endDate!))}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)))
                : _transactions.isEmpty
                    ? const Center(
                        child: Text('Нет операций за этот период',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final amount = double.tryParse(t['amount'].toString()) ?? 0.0;
                          final date = DateTime.tryParse(t['transaction_date'].toString()) ?? DateTime.now();
                          final clientName = t['client_name'] ?? '-';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        clientName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${fmt.format(amount)} KGS',
                                      style: TextStyle(
                                        color: amount < 0 ? Colors.redAccent : Colors.greenAccent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t['description'] ?? 'Без описания',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet_outlined, color: Colors.white38, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${t['debit_account'] ?? '??'} ➔ ${t['credit_account'] ?? '??'}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      DateFormat('dd.MM.yyyy').format(date),
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

extension DateTimeIso on DateTime {
  String toISO() => toIso8601String();
}
extension StringSlice on String {
  String slice(int start, int end) => substring(start, end);
}
