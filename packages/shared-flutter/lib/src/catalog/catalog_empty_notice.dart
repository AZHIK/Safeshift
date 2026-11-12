import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Which catalogue ran out of rows.
enum CatalogKind {
  /// `public.vehicle_types` — the sizes a customer can book.
  vehicles,

  /// `public.cargo_types` — what a customer says they are moving.
  cargo,
}

/// Shown when the catalogue has no active rows for the user's country.
///
/// The catalogues live in the database and the apps carry no built-in list,
/// so an empty catalogue means an empty screen — with an explanation rather
/// than a blank one.
class CatalogEmptyNotice extends StatelessWidget {
  const CatalogEmptyNotice({
    super.key,
    required this.kind,
    this.message,
    this.icon,
  });

  final CatalogKind kind;

  /// Overrides the default wording.
  final String? message;

  final IconData? icon;

  String get _title => switch (kind) {
    CatalogKind.vehicles => 'No vehicles available yet',
    CatalogKind.cargo => 'No cargo types available yet',
  };

  String get _message => switch (kind) {
    CatalogKind.vehicles =>
      'No vehicle categories are published for your market yet. '
          'Please check back shortly.',
    CatalogKind.cargo =>
      'No cargo types are published for your market yet. '
          'You can still book a vehicle and describe the load in the notes.',
  };

  IconData get _icon => switch (kind) {
    CatalogKind.vehicles => Icons.local_shipping_outlined,
    CatalogKind.cargo => Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: SafeShiftColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SafeShiftColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon ?? _icon, size: 20, color: SafeShiftColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SafeShiftColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message ?? _message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: SafeShiftColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
