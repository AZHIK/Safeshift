import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_cargo_categories.dart';
import '../../../shared/mock/mock_drivers.dart';
import '../../../shared/mock/mock_locations.dart';
import '../../../shared/mock/mock_payment_methods.dart';
import '../../../shared/mock/mock_vehicle_classes.dart';
import '../../tracking/domain/entities/driver.dart';

/// Single-screen Bolt-style flow. Everything happens on RideScreen,
/// the bottom sheet just morphs through these stages.
enum RideStage {
  /// Map + "Where to?" + saved places.
  idle,

  /// Pickup + destination chosen, route preview on map.
  route,

  /// Vehicle carousel visible.
  vehicle,

  /// Quote + confirm visible.
  confirm,

  /// Searching for driver (radar).
  searching,

  /// Driver assigned + live tracking.
  tracking,

  /// Delivered / receipt.
  done,
}

class RideState {
  RideState({
    this.stage = RideStage.idle,
    this.pickup,
    this.destination,
    MockVehicleClass? vehicleClass,
    this.cargo,
    this.scheduledLabel = 'Now',
    this.driver,
    this.etaMin = 7,
    this.distanceKm = 8.2,
    this.durationMin = 32,
    this.parcelDescription,
    this.parcelWeightKg,
    this.parcelValueTzs,
    this.parcelPhotoPaths = const <String>[],
    MockPaymentMethod? paymentMethod,
  }) : vehicleClass =
           vehicleClass ??
           (mockVehicleClasses.length > 1
               ? mockVehicleClasses[1]
               : mockVehicleClasses.first),
       paymentMethod = paymentMethod ?? mockPaymentMethods.first;

  final RideStage stage;
  final MockLocation? pickup;
  final MockLocation? destination;
  final MockVehicleClass vehicleClass;
  final MockCargoCategory? cargo;
  final String scheduledLabel;
  final Driver? driver;
  final int etaMin;
  final double distanceKm;
  final int durationMin;
  // Parcel details (filled via dialog, stays on the single screen).
  final String? parcelDescription;
  final double? parcelWeightKg;
  final int? parcelValueTzs;
  final List<String> parcelPhotoPaths;
  // Mock-only Bolt-like payment method. No backend logic.
  final MockPaymentMethod paymentMethod;

  bool get hasRoute => pickup != null && destination != null;
  bool get hasParcelDetails =>
      (parcelDescription?.trim().isNotEmpty ?? false) ||
      parcelWeightKg != null ||
      parcelValueTzs != null ||
      parcelPhotoPaths.isNotEmpty;

  RideState copyWith({
    RideStage? stage,
    MockLocation? pickup,
    MockLocation? destination,
    MockVehicleClass? vehicleClass,
    MockCargoCategory? cargo,
    String? scheduledLabel,
    Driver? driver,
    int? etaMin,
    double? distanceKm,
    int? durationMin,
    String? parcelDescription,
    double? parcelWeightKg,
    int? parcelValueTzs,
    List<String>? parcelPhotoPaths,
    MockPaymentMethod? paymentMethod,
    bool clearDriver = false,
    bool clearParcel = false,
  }) {
    return RideState(
      stage: stage ?? this.stage,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      cargo: cargo ?? this.cargo,
      scheduledLabel: scheduledLabel ?? this.scheduledLabel,
      driver: clearDriver ? null : (driver ?? this.driver),
      etaMin: etaMin ?? this.etaMin,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      parcelDescription: clearParcel
          ? null
          : (parcelDescription ?? this.parcelDescription),
      parcelWeightKg: clearParcel
          ? null
          : (parcelWeightKg ?? this.parcelWeightKg),
      parcelValueTzs: clearParcel
          ? null
          : (parcelValueTzs ?? this.parcelValueTzs),
      parcelPhotoPaths: clearParcel
          ? const <String>[]
          : (parcelPhotoPaths ?? this.parcelPhotoPaths),
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class RideNotifier extends Notifier<RideState> {
  int _searchGen = 0;

  @override
  RideState build() => RideState();

  void setPickup(MockLocation location) {
    state = state.copyWith(pickup: location);
    if (state.hasRoute) state = state.copyWith(stage: RideStage.vehicle);
  }

  void setDestination(MockLocation location) {
    state = state.copyWith(destination: location);
    if (state.hasRoute) state = state.copyWith(stage: RideStage.vehicle);
  }

  void swap() {
    final p = state.pickup;
    final d = state.destination;
    if (p == null || d == null) return;
    state = state.copyWith(pickup: d, destination: p);
  }

  void selectVehicle(MockVehicleClass vehicle) {
    state = state.copyWith(vehicleClass: vehicle, stage: RideStage.confirm);
  }

  void selectCargo(MockCargoCategory cargo) {
    state = state.copyWith(cargo: cargo);
  }

  void setSchedule(String label) {
    state = state.copyWith(scheduledLabel: label);
  }

  /// Mock-only: no backend, just switches the displayed method.
  void selectPaymentMethod(MockPaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setParcelDetails({
    String? description,
    double? weightKg,
    int? valueTzs,
    List<String>? photoPaths,
  }) {
    state = state.copyWith(
      parcelDescription: description ?? state.parcelDescription,
      parcelWeightKg: weightKg ?? state.parcelWeightKg,
      parcelValueTzs: valueTzs ?? state.parcelValueTzs,
      parcelPhotoPaths: photoPaths ?? state.parcelPhotoPaths,
    );
  }

  void clearParcelDetails() {
    state = state.copyWith(clearParcel: true);
  }

  void confirm() {
    if (!state.hasRoute) return;
    state = state.copyWith(stage: RideStage.searching, clearDriver: true);
  }

  /// Bolt-style async search owned by the notifier (not a disposed widget
  /// ref): safe across the AnimatedSwitcher unmount of the confirm view.
  Future<void> confirmAndFindDriver() async {
    if (!state.hasRoute) return;
    final gen = ++_searchGen;
    state = state.copyWith(stage: RideStage.searching, clearDriver: true);
    await Future<void>.delayed(const Duration(seconds: 3));
    // Stale guard: user cancelled / reset / started a new search meanwhile.
    if (gen != _searchGen || state.stage != RideStage.searching) return;
    state = state.copyWith(
      stage: RideStage.tracking,
      driver: mockDrivers.first,
    );
  }

  void cancelSearch() {
    _searchGen++;
    state = state.copyWith(stage: RideStage.vehicle, clearDriver: true);
  }

  void driverFound(Driver driver) {
    state = state.copyWith(stage: RideStage.tracking, driver: driver);
  }

  void complete() {
    state = state.copyWith(stage: RideStage.done);
  }

  void reset() {
    _searchGen++;
    state = RideState();
  }

  void backToRoute() {
    _searchGen++;
    state = state.copyWith(stage: RideStage.vehicle);
  }
}

final rideProvider = NotifierProvider<RideNotifier, RideState>(
  RideNotifier.new,
);

@visibleForTesting
int quoteTotalFor(String vehicleId, int fallback) => fallback;
