// Mock earnings figures in TZS for the driver dashboard.

class DailyEarning {
  const DailyEarning({required this.day, required this.amountTzs});

  final String day;
  final int amountTzs;
}

abstract final class MockEarnings {
  static const int todayTzs = 161000;
  static const int weekTzs = 845000;
  static const int monthTzs = 3120000;

  static const int todayTrips = 3;
  static const int weekTrips = 21;
  static const int monthTrips = 86;

  static const double commissionRate = 0.15;

  static const List<DailyEarning> last7Days = <DailyEarning>[
    DailyEarning(day: 'Mon', amountTzs: 98000),
    DailyEarning(day: 'Tue', amountTzs: 124000),
    DailyEarning(day: 'Wed', amountTzs: 87000),
    DailyEarning(day: 'Thu', amountTzs: 161000),
    DailyEarning(day: 'Fri', amountTzs: 142000),
    DailyEarning(day: 'Sat', amountTzs: 178000),
    DailyEarning(day: 'Sun', amountTzs: 55000),
  ];
}
