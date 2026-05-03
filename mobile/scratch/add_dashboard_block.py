import re

filepath = r'c:\Projects\FinMob\mobile\lib\screens\dashboard_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacement = """
          Container(
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
                _buildTableRow(context, 'ОД', 0, loan.principalBalance),
                _buildTableRow(context, 'Проценты', loan.overdueInterest, loan.accruedInterest),
                _buildTableRow(context, 'Пени', loan.accruedPenalty, loan.accruedPenalty),
                Divider(color: pal.border, height: 16),
                _buildTableRow(context, 'ИТОГО', loan.totalOverdue, loan.fullRepayment, isBold: true),
                const SizedBox(height: 12),
                _infoRow(context, 'Процентная ставка:', '${loan.interestRate}% годовых'),
                const SizedBox(height: 6),
                _infoRow(context, 'Срок кредита:', '${DateFormat('dd.MM.yy').format(loan.issueDate)} — ${DateFormat('dd.MM.yy').format(loan.endDate)}'),
              ],
            ),
          ),
"""

pattern = re.compile(
    r"          Container\(\s*padding: const EdgeInsets\.all\(12\).*?_infoRow\(context, 'Срок кредита:'.*?\],\s*\),\s*\),",
    re.DOTALL
)

new_code = pattern.sub(replacement, code)

helper_method = """
  Widget _buildTableRow(BuildContext context, String label, double v1, double v2, {bool isBold = false}) {
    final pal = AppPalette.of(context);
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final style = TextStyle(
      color: isBold ? pal.textPri : pal.textSec, 
      fontSize: 12, 
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: style)),
          Expanded(flex: 3, child: Text(fmt.format(v1), textAlign: TextAlign.right, style: style.copyWith(color: v1 > 0 ? Colors.redAccent : style.color))),
          Expanded(flex: 3, child: Text(fmt.format(v2), textAlign: TextAlign.right, style: style.copyWith(color: isBold ? Colors.greenAccent : style.color))),
        ],
      ),
    );
  }

  Widget _infoRow"""

new_code = new_code.replace("  Widget _infoRow", helper_method)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Replaced dashboard card")
