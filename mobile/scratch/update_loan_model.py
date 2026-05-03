import re

filepath = r'c:\Projects\FinMob\mobile\lib\models\loan.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacement = """  final double interestRate;    // interest_rate_annual
  final double overdueInterest; // overdue_interest
  final double penaltyOd;       // accrued_penalty_od
  final double penaltyInt;      // accrued_penalty_int
  final Map<String, dynamic>? board;

  const Loan({
    required this.id,
    required this.contractNumber,
    required this.loanAmount,
    required this.principalBalance,
    required this.accruedInterest,
    required this.accruedPenalty,
    required this.issueDate,
    required this.endDate,
    required this.status,
    required this.calculatedStatus,
    this.purpose,
    this.repaymentType,
    this.interestRate = 0.0,
    this.overdueInterest = 0.0,
    this.penaltyOd = 0.0,
    this.penaltyInt = 0.0,
    this.board,
  });

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id:               j['loan_id'].toString(),
        contractNumber:   j['contract_number']?.toString() ?? '—',
        loanAmount:       _d(j['loan_amount']),
        principalBalance: _d(j['principal_balance']),
        accruedInterest:  _d(j['accrued_interest']),
        accruedPenalty:   _d(j['accrued_penalty']),
        issueDate:        j['issue_date'] != null ? DateTime.parse(j['issue_date']) : DateTime.now(),
        endDate:          j['end_date'] != null ? DateTime.parse(j['end_date']) : DateTime.now(),
        status:           j['status']?.toString() ?? '',
        calculatedStatus: j['calculated_status']?.toString() ?? j['status']?.toString() ?? '',
        purpose:          j['purpose']?.toString(),
        repaymentType:    j['repayment_type']?.toString(),
        interestRate:     _d(j['interest_rate_annual']),
        overdueInterest:  _d(j['overdue_interest']),
        penaltyOd:        _d(j['accrued_penalty_od']),
        penaltyInt:       _d(j['accrued_penalty_int']),
        board:            j['board'],
      );"""

pattern = re.compile(
    r"  final double interestRate;.*?penaltyInt:       _d\(j\['accrued_penalty_int'\]\),\s*\);",
    re.DOTALL
)

new_code = pattern.sub(replacement, code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Updated loan.dart")
