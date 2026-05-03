import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacement = """          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? pal.bg.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.03),
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
                    Expanded(flex: 3, child: Text('НАИМЕНОВАНИЕ', style: TextStyle(color: pal.textHint, fontSize: 10))),
                    Expanded(flex: 3, child: Text('ПРОСРОЧКА', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                    Expanded(flex: 3, child: Text('ОСТАТОК', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTableRow(context, 'ОД', _d(loan.board?['od_col1_overdue'] ?? 0), _d(loan.board?['od_col3_full'] ?? loan.principalBalance)),
                _buildTableRow(context, 'Проценты', _d(loan.board?['int_col1'] ?? loan.overdueInterest), _d(loan.board?['int_col3'] ?? loan.accruedInterest)),
                _buildTableRow(context, 'Пени', _d(loan.board?['pen_col1'] ?? loan.accruedPenalty), _d(loan.board?['pen_col3'] ?? loan.accruedPenalty)),
                Divider(color: pal.border, height: 16),
                _buildTableRow(context, 'ИТОГО', _d(loan.board?['total_col1'] ?? loan.totalOverdue), _d(loan.board?['total_col3'] ?? loan.fullRepayment), isBold: true),
                const SizedBox(height: 12),
                _infoRow(context, 'Процентная ставка:', '${loan.interestRate}% годовых'),
                const SizedBox(height: 6),
                _infoRow(context, 'Срок кредита:', '${DateFormat('dd.MM.yy').format(loan.issueDate)} — ${DateFormat('dd.MM.yy').format(loan.endDate)}'),
              ],
            ),
          ),"""

pattern = re.compile(
    r"          Container\(\s*padding: const EdgeInsets\.all\(12\).*?_infoRow\(context, 'Срок кредита:'.*?\],\s*\),\s*\),",
    re.DOTALL
)

new_code = pattern.sub(replacement, code)

# add _d helper in _LoanCard or just use double.tryParse? Actually I can use a double parser directly in the script
replacement_with_parse = replacement.replace("_d(", "(double.tryParse(('")
replacement_with_parse = replacement_with_parse.replace("?? 0)", "')?.toString() ?? '0') ?? 0.0)")
replacement_with_parse = replacement_with_parse.replace("?? loan", "')?.toString() ?? '0') ?? loan")
# wait, replacing _d is error prone. Let's write a small inner helper function or just use loan.board values as double since it comes from json.

better_replacement = """          Container(
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
                
                final odOverdue = safe(loan.board?['od_col1_overdue'], 0);
                final odFull = safe(loan.board?['od_col3_full'], loan.principalBalance);
                
                final intOverdue = safe(loan.board?['int_col1'], loan.overdueInterest);
                final intFull = safe(loan.board?['int_col3'], loan.accruedInterest);
                
                final penOverdue = safe(loan.board?['pen_col1'], loan.accruedPenalty);
                final penFull = safe(loan.board?['pen_col3'], loan.accruedPenalty);
                
                final totalOverdue = safe(loan.board?['total_col1'], loan.totalOverdue);
                final totalFull = safe(loan.board?['total_col3'], loan.fullRepayment);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Информационное табло', style: TextStyle(color: pal.textSec, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 3, child: Text('НАИМЕНОВАНИЕ', style: TextStyle(color: pal.textHint, fontSize: 10))),
                        Expanded(flex: 3, child: Text('ПРОСРОЧКА', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                        Expanded(flex: 3, child: Text('ОСТАТОК', textAlign: TextAlign.right, style: TextStyle(color: pal.textHint, fontSize: 10))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTableRow(context, 'ОД', odOverdue, odFull),
                    _buildTableRow(context, 'Проценты', intOverdue, intFull),
                    _buildTableRow(context, 'Пени', penOverdue, penFull),
                    Divider(color: pal.border, height: 16),
                    _buildTableRow(context, 'ИТОГО', totalOverdue, totalFull, isBold: true),
                    const SizedBox(height: 12),
                    _infoRow(context, 'Процентная ставка:', '${loan.interestRate}% годовых'),
                    const SizedBox(height: 6),
                    _infoRow(context, 'Срок кредита:', '${DateFormat('dd.MM.yy').format(loan.issueDate)} — ${DateFormat('dd.MM.yy').format(loan.endDate)}'),
                  ],
                );
              }
            ),
          ),"""

new_code = pattern.sub(better_replacement, code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Updated dashboard_screen.dart")
