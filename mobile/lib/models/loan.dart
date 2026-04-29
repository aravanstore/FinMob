/// Кредитный договор (маппинг таблицы loans AURUM)
class Loan {
  final String id;              // loan_id (UUID)
  final String contractNumber;  // contract_number
  final double loanAmount;      // loan_amount — исходная сумма
  final double principalBalance;// principal_balance — остаток долга
  final double accruedInterest; // accrued_interest
  final double accruedPenalty;  // accrued_penalty
  final DateTime issueDate;     // issue_date
  final DateTime endDate;       // end_date
  final String status;          // status из БД
  final String calculatedStatus;// calculated_status (Просрочен / Активен / Погашен)
  final String? purpose;        // цель кредита
  final String? repaymentType;  // Аннуитет / Равные доли

  final double interestRate;    // interest_rate_annual
  final double overdueInterest; // overdue_interest
  final double penaltyOd;       // accrued_penalty_od
  final double penaltyInt;      // accrued_penalty_int

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
  });

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id:               j['loan_id'].toString(),
        contractNumber:   j['contract_number']?.toString() ?? '—',
        loanAmount:       _d(j['loan_amount']),
        principalBalance: _d(j['principal_balance']),
        accruedInterest:  _d(j['accrued_interest']),
        accruedPenalty:   _d(j['accrued_penalty']),
        issueDate:        DateTime.parse(j['issue_date']),
        endDate:          DateTime.parse(j['end_date']),
        status:           j['status']?.toString() ?? '',
        calculatedStatus: j['calculated_status']?.toString() ?? j['status']?.toString() ?? '',
        purpose:          j['purpose']?.toString(),
        repaymentType:    j['repayment_type']?.toString(),
        interestRate:     _d(j['interest_rate_annual']),
        overdueInterest:  _d(j['overdue_interest']),
        penaltyOd:        _d(j['accrued_penalty_od']),
        penaltyInt:       _d(j['accrued_penalty_int']),
      );

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  bool get isOverdue => calculatedStatus == 'Просрочен';
  bool get isPaid    => calculatedStatus == 'Погашен' || status == 'Погашен';
  bool get isActive  => !isOverdue && !isPaid;

  /// Процент выплаченности: (исходная - остаток) / исходная
  double get paidPercent =>
      loanAmount > 0 ? ((loanAmount - principalBalance) / loanAmount).clamp(0.0, 1.0) : 0.0;

  /// Общая задолженность
  double get totalDebt => principalBalance;

  /// Просроченные проценты и пени
  double get totalOverdue => overdueInterest + accruedPenalty + penaltyOd + penaltyInt;

  /// Полное погашение на текущий день
  double get fullRepayment => principalBalance + accruedInterest + totalOverdue;
}
