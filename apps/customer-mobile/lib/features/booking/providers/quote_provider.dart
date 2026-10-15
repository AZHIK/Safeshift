import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_quotes.dart';
import '../domain/entities/quote.dart';
import 'booking_provider.dart';

final quoteProvider = Provider<Quote?>((ref) {
  final draft = ref.watch(bookingProvider);
  if (draft == null) return null;
  for (final quote in mockQuotes) {
    if (quote.vehicleClassId == draft.vehicleClass.id) return quote;
  }
  return null;
});
