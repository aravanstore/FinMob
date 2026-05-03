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
          ),"""

pattern = re.compile(
    r"          Container\(\s*padding: const EdgeInsets\.all\(12\).*?_infoRow\(context, 'Срок кредита:'.*?\],\s*\);\s*\}\s*\),\s*\),",
    re.DOTALL
)

new_code = pattern.sub(replacement, code)

helper_replacement = """  Widget _buildTableRow(BuildContext context, String label, double v1, double v2, double v3, {bool isBold = false}) {
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
  }"""

new_code = re.sub(
    r"  Widget _buildTableRow\(BuildContext context, String label, double v1, double v2, \{bool isBold = false\}\) \{.*?    \);\n  \}",
    helper_replacement,
    new_code,
    flags=re.DOTALL
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Updated dashboard_screen.dart")
