// Mock customer ratings for the driver.

class MockRating {
  const MockRating({
    required this.customerName,
    required this.stars,
    required this.comment,
    required this.date,
  });

  final String customerName;
  final int stars;
  final String comment;
  final DateTime date;
}

List<MockRating> get mockRatings => <MockRating>[
  MockRating(
    customerName: 'Neema',
    stars: 5,
    comment: 'Very careful with my furniture. Arrived on time.',
    date: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  MockRating(
    customerName: 'David',
    stars: 5,
    comment: 'Professional driver, helped with loading.',
    date: DateTime.now().subtract(const Duration(hours: 7)),
  ),
  MockRating(
    customerName: 'Zawadi',
    stars: 4,
    comment: 'Good trip, slight delay in traffic.',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  MockRating(
    customerName: 'Juma',
    stars: 5,
    comment: 'Excellent service, will book again.',
    date: DateTime.now().subtract(const Duration(days: 2)),
  ),
  MockRating(
    customerName: 'Asha',
    stars: 5,
    comment: 'Kept me updated the whole way.',
    date: DateTime.now().subtract(const Duration(days: 4)),
  ),
  MockRating(
    customerName: 'Kelvin',
    stars: 5,
    comment: 'Handled fragile electronics well.',
    date: DateTime.now().subtract(const Duration(days: 8)),
  ),
  MockRating(
    customerName: 'Ibrahim',
    stars: 4,
    comment: 'Fair price and safe driving.',
    date: DateTime.now().subtract(const Duration(days: 12)),
  ),
  MockRating(
    customerName: 'Fatma',
    stars: 3,
    comment: 'Okay trip, arrived a bit late.',
    date: DateTime.now().subtract(const Duration(days: 20)),
  ),
];
