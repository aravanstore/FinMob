import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\staff\loan_details_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacement = """
          final amount   = double.tryParse(loan['loan_amount']?.toString() ?? '0') ?? 0;
          final balance  = double.tryParse(loan['principal_balance']?.toString() ?? '0') ?? 0;
          final interest = double.tryParse(loan['accrued_interest']?.toString() ?? '0') ?? 0;
          final penalty  = double.tryParse(loan['accrued_penalty']?.toString() ?? '0') ?? 0;
          
          final overdueInt = double.tryParse(loan['overdue_interest']?.toString() ?? '0') ?? 0;
          final interestRate = loan['interest_rate_annual'] ?? loan['interest_rate'] ?? '0';

          final now = DateTime.now();
          final eom = DateTime(now.year, now.month + 1, 0);

          double overdueOd = 0;
          double eomOd = 0;
          double eomInt = overdueInt + interest;

          for (var s in schedule) {
            if (s['is_paid'] == true) continue;
            final d = DateTime.tryParse(s['payment_date'].toString());
            if (d == null) continue;
            final pAmt = double.tryParse(s['principal_amount']?.toString() ?? '0') ?? 0;
            if (d.isBefore(now)) overdueOd += pAmt;
            if (d.isBefore(eom) || d.isAtSameMomentAs(eom)) eomOd += pAmt;
          }

          return Column(
            children: [
              // Главная карточка
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pal.surface, pal.card],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pal.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('КД-${loan['contract_number']}', style: TextStyle(color: pal.textPri, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(loan['full_name'] ?? '', style: TextStyle(color: pal.textSec, fontSize: 13)),
                          ],
                        ),
                        _StatusBadge(status: loan['status']),
                      ],
                    ),
                    Divider(color: pal.border, height: 24),
                    
                    // Информационное табло как в AURUM
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.bg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Информационное табло', style: TextStyle(color: pal.textSec, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(flex: 2, child: Text('НАИМЕНОВАНИЕ', style: TextStyle(color: pal.textHint, fontSize: 10))),
                              Expanded(flex: 2, child: Text('ПРОСРОЧКА', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                              Expanded(flex: 2, child: Text('К КОНЦУ МЕС.', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                              Expanded(flex: 2, child: Text('ПОЛНОЕ', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTableRow('ОД', overdueOd, eomOd, balance, fmt, pal),
                          _buildTableRow('Проценты', overdueInt, eomInt, overdueInt + interest, fmt, pal),
                          _buildTableRow('Пени', penalty, penalty, penalty, fmt, pal),
                          Divider(color: pal.border, height: 16),
                          _buildTableRow('ИТОГО', overdueOd + overdueInt + penalty, eomOd + eomInt + penalty, balance + overdueInt + interest + penalty, fmt, pal, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Подробности: Выдано, Срок и т.д.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _InfoTile(label: 'Выдано', value: fmt.format(amount)),
                    const SizedBox(width: 12),
                    _InfoTile(label: 'Окончание', value: loan['end_date'] != null ? df.format(DateTime.parse(loan['end_date'])) : '-'),
                    const SizedBox(width: 12),
                    _InfoTile(label: 'Ставка', value: '$interestRate%'),
                  ],
                ),
              ),
"""

pattern = re.compile(
    r"          final amount   = double\.tryParse.*?_InfoTile\(label: 'Ставка', value: '\$\{loan\['interest_rate'\] \?\? '0'\}%'\),\s*\],\s*\),\s*\),",
    re.DOTALL
)

new_code = pattern.sub(replacement, code)

# add _buildTableRow helper inside _LoanDetailsScreenState
helper_method = """
  Widget _buildTableRow(String label, double v1, double v2, double v3, NumberFormat fmt, AppPalette pal, {bool isBold = false}) {
    final style = TextStyle(
      color: isBold ? pal.textPri : pal.textSec, 
      fontSize: 12, 
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: style)),
          Expanded(flex: 2, child: Text(fmt.format(v1), textAlign: TextAlign.right, style: style.copyWith(color: v1 > 0 && label == 'ПРОСРОЧКА' ? Colors.redAccent : style.color))),
          Expanded(flex: 2, child: Text(fmt.format(v2), textAlign: TextAlign.right, style: style)),
          Expanded(flex: 2, child: Text(fmt.format(v3), textAlign: TextAlign.right, style: style.copyWith(color: isBold ? Colors.greenAccent : style.color))),
        ],
      ),
    );
  }

  Widget _buildScheduleList"""

new_code = new_code.replace("  Widget _buildScheduleList", helper_method)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Replaced!")
