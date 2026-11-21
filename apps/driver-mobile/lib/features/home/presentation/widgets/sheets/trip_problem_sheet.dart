import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/driver_status.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Problems a driver can resolve before the cargo is loaded:
/// hand the job back, report a customer no-show, or refuse cargo that does
/// not match the booking.
Future<void> showTripProblemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _TripProblemSheet(),
  );
}

class _TripProblemSheet extends ConsumerWidget {
  const _TripProblemSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final status = home.driverStatus;
    final atPickup = status == DriverStatus.arrivedAtPickup;
    final canRelease = status == DriverStatus.headingToPickup || atPickup;
    final canRefuseCargo = atPickup || status == DriverStatus.cargoVerified;
    final waitEnds = home.pickupFreeWaitEndsAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const Text('What went wrong?', style: TextStyles.title),
          const SizedBox(height: AppSizes.sm),
          if (atPickup)
            _NoShowTile(waitEnds: waitEnds, enabled: !home.isSubmitting),
          if (canRefuseCargo)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text("Cargo doesn't match the booking"),
              subtitle: const Text(
                'Too big, too heavy, or not allowed in your vehicle',
              ),
              enabled: !home.isSubmitting,
              onTap: () => _refuseCargo(context, ref),
            ),
          if (canRelease)
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text("I can't do this job"),
              subtitle: const Text(
                'We will give it to another driver. Releasing jobs often '
                'affects your acceptance rate.',
              ),
              enabled: !home.isSubmitting,
              onTap: () => _release(context, ref),
            ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Something else'),
            subtitle: const Text('Contact SafeShift support'),
            onTap: () => AppSnackbar.showInfo(
              context,
              'Support chat is not available yet',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    const reasons = <String>[
      'Vehicle problem',
      'Personal emergency',
      'Pickup is too far or traffic is too heavy',
      'Customer asked me to cancel',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Why can\'t you do this job?'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(r),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final ok = await ref.read(homeProvider.notifier).releaseActiveJob(reason);
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _refuseCargo(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(
        title: 'What does not match?',
        hint: 'For example: a fridge instead of 3 boxes, about 300 kg',
        confirmLabel: 'Refuse cargo',
      ),
    );
    if (reason == null || !context.mounted) return;
    final ok = await ref
        .read(homeProvider.notifier)
        .reportCargoMismatch(reason);
    if (ok && context.mounted) Navigator.of(context).pop();
  }
}

class _NoShowTile extends ConsumerStatefulWidget {
  const _NoShowTile({required this.waitEnds, required this.enabled});

  final DateTime? waitEnds;
  final bool enabled;

  @override
  ConsumerState<_NoShowTile> createState() => _NoShowTileState();
}

class _NoShowTileState extends ConsumerState<_NoShowTile> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ends = widget.waitEnds;
    final left = ends?.difference(DateTime.now());
    final ready = left != null && left.isNegative;
    final subtitle = ends == null
        ? 'Checking your waiting time…'
        : ready
        ? 'You waited the full free time. The customer pays the '
              'cancellation fee.'
        : 'Available in ${_format(left!)}. Try calling the customer first.';
    return ListTile(
      leading: const Icon(Icons.person_off_outlined),
      title: const Text("Customer didn't show up"),
      subtitle: Text(subtitle),
      enabled: widget.enabled && ready,
      onTap: () => _confirm(context),
    );
  }

  static String _format(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report a no-show?'),
        content: const Text(
          'This cancels the move as a customer no-show. Only do this if you '
          'could not reach the customer at the pickup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep waiting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Report no-show'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await ref.read(homeProvider.notifier).reportCustomerNoShow();
    if (done && context.mounted) Navigator.of(context).pop();
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 300,
        maxLines: 3,
        minLines: 2,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().length < 3
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
