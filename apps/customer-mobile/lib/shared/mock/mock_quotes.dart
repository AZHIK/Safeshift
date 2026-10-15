// TODO: replace with pricing API data in a later sprint. Sample quotes only,
// with amounts in TZS.
import '../../features/booking/domain/entities/quote.dart';

const List<Quote> mockQuotes = <Quote>[
  Quote(
    baseFee: 25000,
    distanceFee: 8000,
    timeFee: 3000,
    cargoHandlingFee: 2000,
    vat: 6840,
    total: 44840,
    vehicleClassId: 'small_van',
  ),
  Quote(
    baseFee: 40000,
    distanceFee: 12000,
    timeFee: 5000,
    cargoHandlingFee: 3500,
    vat: 10890,
    total: 71390,
    vehicleClassId: 'pickup',
  ),
  Quote(
    baseFee: 75000,
    distanceFee: 18000,
    timeFee: 8000,
    cargoHandlingFee: 6000,
    vat: 19260,
    total: 126260,
    vehicleClassId: 'medium_truck',
  ),
  Quote(
    baseFee: 120000,
    distanceFee: 25000,
    timeFee: 12000,
    cargoHandlingFee: 9000,
    vat: 29880,
    total: 195880,
    vehicleClassId: 'large_truck',
  ),
];
