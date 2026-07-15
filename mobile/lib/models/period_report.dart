class PeriodReport {
  final String period;
  final String label;
  final String startDate;
  final String endDate;
  final int tripCount;
  final double totalMiles;
  final double totalTips;
  final double mileageRate;
  final double mileageExpense;
  final double earningsPerMile;
  final double netEarnings;

  const PeriodReport({
    required this.period,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.tripCount,
    required this.totalMiles,
    required this.totalTips,
    required this.mileageRate,
    required this.mileageExpense,
    required this.earningsPerMile,
    required this.netEarnings,
  });

  factory PeriodReport.fromJson(Map<String, dynamic> json) {
    return PeriodReport(
      period: json['period'] as String,
      label: json['label'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      tripCount: json['trip_count'] as int,
      totalMiles: (json['total_miles'] as num).toDouble(),
      totalTips: (json['total_tips'] as num).toDouble(),
      mileageRate: (json['mileage_rate'] as num).toDouble(),
      mileageExpense: (json['mileage_expense'] as num).toDouble(),
      earningsPerMile: (json['earnings_per_mile'] as num).toDouble(),
      netEarnings: (json['net_earnings'] as num).toDouble(),
    );
  }
}

class ReportSummary {
  final String referenceDate;
  final PeriodReport weekly;
  final PeriodReport monthly;
  final PeriodReport annual;

  const ReportSummary({
    required this.referenceDate,
    required this.weekly,
    required this.monthly,
    required this.annual,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      referenceDate: json['reference_date'] as String,
      weekly: PeriodReport.fromJson(json['weekly'] as Map<String, dynamic>),
      monthly: PeriodReport.fromJson(json['monthly'] as Map<String, dynamic>),
      annual: PeriodReport.fromJson(json['annual'] as Map<String, dynamic>),
    );
  }
}