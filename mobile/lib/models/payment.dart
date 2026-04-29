/// Строка графика платежей (маппинг таблицы loan_schedules AURUM)
class Payment {
  final String scheduleId;      // schedule_id (UUID)
  final int paymentNumber;      // payment_number
  final DateTime paymentDate;   // payment_date
  final double principalAmount; // principal_amount
  final double interestAmount;  // interest_amount
  final double totalAmount;     // total_amount
  final bool isPaid;            // is_paid
  final DateTime? paidDate;     // paid_date
  final String status;          // 'paid' | 'overdue' | 'pending'

  const Payment({
    required this.scheduleId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.principalAmount,
    required this.interestAmount,
    required this.totalAmount,
    required this.isPaid,
    this.paidDate,
    required this.status,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        scheduleId:      j['schedule_id'].toString(),
        paymentNumber:   (j['payment_number'] as num).toInt(),
        paymentDate:     DateTime.parse(j['payment_date']),
        principalAmount: _d(j['principal_amount']),
        interestAmount:  _d(j['interest_amount']),
        totalAmount:     _d(j['total_amount']),
        isPaid:          j['is_paid'] == true,
        paidDate:        j['paid_date'] != null ? DateTime.parse(j['paid_date']) : null,
        status:          j['status']?.toString() ?? 'pending',
      );

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  bool get isOverdue => status == 'overdue';
}
