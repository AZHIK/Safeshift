import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeliveryPhase { verify, receipt }

class DeliveryState {
  const DeliveryState({
    this.phase = DeliveryPhase.verify,
    this.isLoading = false,
  });
  final DeliveryPhase phase;
  final bool isLoading;
}

class DeliveryNotifier extends Notifier<DeliveryState> {
  @override
  DeliveryState build() => const DeliveryState();

  Future<void> confirmDelivery() async {
    if (state.isLoading || state.phase == DeliveryPhase.receipt) return;
    state = const DeliveryState(isLoading: true);
    await Future<void>.delayed(const Duration(seconds: 2));
    state = const DeliveryState(phase: DeliveryPhase.receipt);
  }
}

final deliveryProvider = NotifierProvider<DeliveryNotifier, DeliveryState>(
  DeliveryNotifier.new,
);
