import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/booking/domain/entities/job.dart';
import 'package:safeshift_customer/features/history/providers/history_provider.dart';

class _FakeHistoryNotifier extends HistoryNotifier {
  @override
  Future<List<Job>> build() async => const <Job>[
    Job(
      id: 'j1',
      status: 'completed',
      pickupAddress: 'A',
      destinationAddress: 'B',
      quoteAmount: 10000,
    ),
    Job(
      id: 'j2',
      status: 'cancelled',
      pickupAddress: 'A',
      destinationAddress: 'C',
      quoteAmount: 12000,
    ),
    Job(
      id: 'j3',
      status: 'in_transit',
      pickupAddress: 'A',
      destinationAddress: 'D',
      quoteAmount: 14000,
    ),
  ];
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [historyProvider.overrideWith(_FakeHistoryNotifier.new)],
    );
    addTearDown(container.dispose);
  });

  test('history filters completed, cancelled, and in-progress jobs', () async {
    await container.read(historyProvider.future);

    container.read(historyFilterProvider.notifier).select('All');
    expect(container.read(filteredHistoryProvider).value, hasLength(3));

    container.read(historyFilterProvider.notifier).select('Completed');
    expect(container.read(filteredHistoryProvider).value, hasLength(1));
    expect(container.read(filteredHistoryProvider).value!.first.id, 'j1');

    container.read(historyFilterProvider.notifier).select('Cancelled');
    expect(container.read(filteredHistoryProvider).value, hasLength(1));
    expect(container.read(filteredHistoryProvider).value!.first.id, 'j2');

    container.read(historyFilterProvider.notifier).select('In Progress');
    expect(container.read(filteredHistoryProvider).value, hasLength(1));
    expect(container.read(filteredHistoryProvider).value!.first.id, 'j3');
  });
}
