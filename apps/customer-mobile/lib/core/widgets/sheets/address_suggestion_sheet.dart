import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/controllers/place_search_controller.dart';
import '../../../shared/models/place_suggestion.dart';
import '../../../shared/models/ride_place.dart';
import '../../../shared/models/user_location.dart';
import '../../../shared/providers/location_provider.dart';
import '../../../shared/providers/places_provider.dart';
import '../../../shared/utils/geo.dart';
import '../../../shared/widgets/location_picker_screen.dart';

/// Opens the shared pickup/delivery place search.
///
/// Both pickup and destination call this same sheet. Each call creates a new
/// [PlaceSearchController], so selection state and search sessions are
/// independent.
Future<void> showAddressSuggestionSheet({
  required BuildContext context,
  required ValueChanged<RidePlace> onSelected,
  String title = 'Choose a location',
  String hintText = 'Search for a place, street, or landmark',
  GeoPoint? initialReference,
  String? language,
}) {
  final resolvedLanguage =
      language ?? Localizations.localeOf(context).languageCode;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddressSuggestionSheet(
      onSelected: onSelected,
      title: title,
      hintText: hintText,
      initialReference: initialReference,
      language: resolvedLanguage,
    ),
  );
}

class AddressSuggestionSheet extends ConsumerStatefulWidget {
  const AddressSuggestionSheet({
    super.key,
    required this.onSelected,
    this.title = 'Choose a location',
    this.hintText = 'Search for a place, street, or landmark',
    this.initialReference,
    this.language = 'en',
  });

  final ValueChanged<RidePlace> onSelected;
  final String title;
  final String hintText;
  final GeoPoint? initialReference;

  /// Provider language for address components (for example `en` or `sw`).
  final String language;

  @override
  ConsumerState<AddressSuggestionSheet> createState() =>
      _AddressSuggestionSheetState();
}

class _AddressSuggestionSheetState extends ConsumerState<AddressSuggestionSheet>
    with WidgetsBindingObserver {
  late final PlaceSearchController _search;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  UserLocation? _currentLocation;
  bool _awaitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = ref.read(authProvider).currentUser;
    final cached = ref.read(currentLocationProvider).location;
    _currentLocation = cached;
    _search = PlaceSearchController(
      repository: ref.read(placesRepositoryProvider),
      profileId: user?.id,
      reference: widget.initialReference ?? cached?.point,
      language: widget.language,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      unawaited(_refreshLocationSilently());
    }
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    final location = await ref
        .read(currentLocationProvider.notifier)
        .ensureLocation(requestPermission: true);
    if (!mounted || location == null) return;
    _currentLocation = location;
    _search.setReference(location.point);
  }

  Future<void> _refreshLocationSilently() async {
    final location = await ref
        .read(currentLocationProvider.notifier)
        .ensureLocation(forceRefresh: true, requestPermission: true);
    if (!mounted || location == null) return;
    setState(() => _currentLocation = location);
    _search.setReference(location.point);
  }

  Future<void> _useCurrentLocation() async {
    final notifier = ref.read(currentLocationProvider.notifier);
    var state = ref.read(currentLocationProvider);
    if (state.isLoading) return;

    if (state.needsSettings) {
      await _showLocationRecoveryDialog(state);
      return;
    }

    if (state.status == LocationStatus.permissionDenied) {
      // The customer explicitly tapped the location row, so it is appropriate
      // to show the permission prompt again.
      notifier.reset();
      state = ref.read(currentLocationProvider);
    }

    // Never silently use a stale fix as a courier point. A cached fix is only
    // reused while it is fresh; otherwise request a new one.
    final cached = state.location;
    final location = cached != null && !cached.isStale
        ? cached
        : await notifier.ensureLocation(
            forceRefresh: true,
            requestPermission: true,
          );
    if (!mounted) return;
    if (location == null) {
      final latest = ref.read(currentLocationProvider);
      if (latest.needsSettings) {
        await _showLocationRecoveryDialog(latest);
      } else {
        _showSnack(latest.message ?? 'Your location is unavailable right now.');
      }
      return;
    }

    _currentLocation = location;
    _search.setReference(location.point);
    await _confirmAndUseLocation(location);
  }

  Future<void> _refreshCurrentLocation() async {
    final notifier = ref.read(currentLocationProvider.notifier);
    final location = await notifier.refresh();
    if (!mounted) return;
    if (location == null) {
      final state = ref.read(currentLocationProvider);
      if (state.needsSettings) {
        await _showLocationRecoveryDialog(state);
      } else {
        _showSnack(state.message ?? 'Your location is unavailable right now.');
      }
      return;
    }
    setState(() => _currentLocation = location);
    _search.setReference(location.point);
    // Refreshing updates the row and proximity bias. The customer still taps
    // the row to confirm it as the pickup/delivery point.
  }

  Future<void> _confirmAndUseLocation(UserLocation location) async {
    final needsConfirmation =
        location.isPoorAccuracy ||
        location.isLastKnown ||
        location.isStale ||
        location.isMocked;
    if (needsConfirmation) {
      final choice = await _showLocationQualityDialog(location);
      if (!mounted || choice == null || choice == _LocationChoice.cancel) {
        return;
      }
      if (choice == _LocationChoice.refine) {
        await _openMapPicker(location.point);
        return;
      }
    }

    final place = await _search.resolveCurrentLocation(location);
    if (!mounted) return;
    if (place == null) {
      _showSnack(
        _search.errorMessage ?? 'Could not use your current location.',
      );
      return;
    }
    _selectPlace(place);
  }

  Future<_LocationChoice?> _showLocationQualityDialog(UserLocation location) {
    final reasons = <String>[];
    if (location.isPoorAccuracy) {
      reasons.add(
        'GPS accuracy is about ${location.accuracyLabel}, which may be too '
        'wide for a courier to find the exact point.',
      );
    }
    if (location.isLastKnown || location.isStale) {
      reasons.add('This is an older fix from ${location.ageLabel}.');
    }
    if (location.isMocked) {
      reasons.add('Your device reports a simulated location.');
    }

    return showDialog<_LocationChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check your location'),
        content: Text(
          '${reasons.join(' ')}\n\nYou can refine the pin on the map before '
          'confirming.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, _LocationChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _LocationChoice.refine),
            child: const Text('Refine on map'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _LocationChoice.useAnyway),
            child: const Text('Use anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationRecoveryDialog(LocationState state) async {
    final isService = state.status == LocationStatus.serviceDisabled;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isService ? 'Location is off' : 'Location permission is off',
        ),
        content: Text(
          state.message ?? 'Open settings to enable location services.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isService ? 'Open settings' : 'Open app settings'),
          ),
        ],
      ),
    );
    if (open != true || !mounted) return;

    _awaitingSettings = true;
    final notifier = ref.read(currentLocationProvider.notifier);
    if (isService) {
      await notifier.openLocationSettings();
    } else {
      await notifier.openAppSettings();
    }
    if (!mounted) return;
    notifier.reset();
  }

  Future<void> _openMapPicker(GeoPoint initial) async {
    final place = await showLocationPicker(
      context: context,
      initial: initial,
      title: 'Refine location',
    );
    if (!mounted || place == null) return;
    _selectPlace(place);
  }

  GeoPoint get _mapInitialPoint {
    final location =
        _currentLocation ?? ref.read(currentLocationProvider).location;
    if (location != null) return location.point;
    final reference = _search.reference;
    if (reference != null) return reference;
    return const GeoPoint(-6.7924, 39.2083);
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final place = await _search.selectSuggestion(suggestion);
    if (!mounted || place == null) return;
    _selectPlace(place);
  }

  void _selectPlace(RidePlace place) {
    widget.onSelected(place);
    Navigator.of(context).pop();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(currentLocationProvider, (previous, next) {
      final location = next.location;
      if (location != null) {
        _currentLocation = location;
        _search.setReference(location.point);
      }
    });

    final locationState = ref.watch(currentLocationProvider);
    final media = MediaQuery.of(context);
    final availableHeight =
        (media.size.height -
                media.viewInsets.bottom -
                media.padding.top -
                media.padding.bottom)
            .clamp(240.0, media.size.height)
            .toDouble();
    final preferredHeight = media.size.height * 0.88;
    final height = availableHeight < preferredHeight
        ? availableHeight
        : preferredHeight;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListenableBuilder(
            listenable: _search,
            builder: (context, _) => Column(
              children: <Widget>[
                _DragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    0,
                    AppSizes.sm,
                    0,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.title.copyWith(fontSize: 18),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pick on map',
                        onPressed: () => _openMapPicker(_mapInitialPoint),
                        icon: const Icon(Icons.map_outlined),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _search.updateQuery,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _textController.clear();
                                _search.updateQuery('');
                                _focusNode.requestFocus();
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.sm,
                    AppSizes.lg,
                    0,
                  ),
                  child: Row(
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Tanzania'),
                        selected: !_search.worldwide,
                        onSelected: (_) => _search.setWorldwide(false),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      ChoiceChip(
                        label: const Text('Worldwide'),
                        selected: _search.worldwide,
                        onSelected: (_) => _search.setWorldwide(true),
                      ),
                      const Spacer(),
                      if (!_search.isProviderConfigured)
                        const Tooltip(
                          message:
                              'Live place search is unavailable. Saved places '
                              'and SafeShift areas still work.',
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.sm,
                    AppSizes.lg,
                    0,
                  ),
                  child: _CurrentLocationTile(
                    state: locationState,
                    onUse: _useCurrentLocation,
                    onRefresh: _refreshCurrentLocation,
                    onSettings: () =>
                        _showLocationRecoveryDialog(locationState),
                  ),
                ),
                if (_search.usingFallback)
                  _InfoBanner(
                    icon: Icons.info_outline_rounded,
                    message:
                        'Showing saved places and SafeShift areas. Live place '
                        'search is unavailable right now.',
                    onRetry: _search.retry,
                  ),
                if (_search.errorMessage != null &&
                    _search.suggestions.isNotEmpty)
                  _InfoBanner(
                    icon: Icons.cloud_off_rounded,
                    message: _search.errorMessage!,
                    isError: true,
                    onRetry: _search.retry,
                  ),
                Expanded(child: _buildResults()),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: AppSizes.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _search.usingFallback
                            ? 'Saved SafeShift places'
                            : 'Powered by Google',
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final query = _search.query.trim();

    if (query.isEmpty) {
      if (_search.isLoadingSaved) {
        return const Center(child: CircularProgressIndicator());
      }

      final saved = _search.savedSuggestions;
      if (saved.isEmpty) {
        return _EmptyState(
          icon: Icons.travel_explore_rounded,
          title: 'Search for a place',
          message:
              _search.savedErrorMessage ??
              'Type a landmark, street, business, or neighbourhood. Results '
                  'are ranked near your current location when location access '
                  'is available.',
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.md,
        ),
        children: <Widget>[
          Text(
            'Saved places',
            style: TextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          for (final suggestion in saved) ...<Widget>[
            _SuggestionTile(
              suggestion: suggestion,
              isResolving:
                  _search.resolvingPlaceId == suggestion.placeId &&
                  suggestion.placeId.isNotEmpty,
              onTap: () => _selectSuggestion(suggestion),
            ),
            const Divider(height: 1),
          ],
        ],
      );
    }

    if (!_search.hasQuery) {
      return const _EmptyState(
        icon: Icons.search_rounded,
        title: 'Keep typing',
        message: 'Type at least two characters to search for a place.',
      );
    }

    if (_search.isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: AppSizes.sm),
              Text('Searching near you…'),
            ],
          ),
        ),
      );
    }

    final suggestions = _search.suggestions;
    if (suggestions.isEmpty) {
      if (_search.errorMessage != null) {
        return _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Search is unavailable',
          message: _search.errorMessage!,
          actionLabel: 'Try again',
          onAction: _search.retry,
        );
      }
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No places found',
        message: _search.worldwide
            ? 'Try a different name or spelling.'
            : 'Try a different name, or search worldwide for places outside '
                  'Tanzania.',
        actionLabel: _search.worldwide ? null : 'Search worldwide',
        onAction: _search.worldwide ? null : () => _search.setWorldwide(true),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return _SuggestionTile(
          suggestion: suggestion,
          isResolving:
              _search.resolvingPlaceId == suggestion.placeId &&
              suggestion.placeId.isNotEmpty,
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
}

enum _LocationChoice { cancel, refine, useAnyway }

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.sm, bottom: AppSizes.xs),
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );
}

class _CurrentLocationTile extends StatelessWidget {
  const _CurrentLocationTile({
    required this.state,
    required this.onUse,
    required this.onRefresh,
    required this.onSettings,
  });

  final LocationState state;
  final VoidCallback onUse;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final location = state.location;
    final isReady = state.status == LocationStatus.ready && location != null;
    final isLoading = state.isLoading;
    final needsSettings = state.needsSettings;

    final title = isLoading
        ? 'Getting your location…'
        : isReady
        ? 'Use my current location'
        : needsSettings
        ? state.status == LocationStatus.serviceDisabled
              ? 'Turn on location'
              : 'Enable location permission'
        : 'Use my current location';

    final subtitle = isLoading
        ? 'Checking GPS and permission…'
        : isReady
        ? '${location.accuracyLabel} · ${location.ageLabel}'
              '${location.isPoorAccuracy ? ' · Low accuracy' : ''}'
        : state.message ?? 'Search results will not be ranked near you.';

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : (needsSettings ? onSettings : onUse),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.xs,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReady
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.title.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isReady)
                IconButton(
                  tooltip: 'Refresh location',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                )
              else if (needsSettings)
                const Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.isResolving,
    required this.onTap,
  });

  final PlaceSuggestion suggestion;
  final bool isResolving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = formatDistanceMeters(suggestion.distanceMeters);
    return Material(
      color: AppColors.surface,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _suggestionIcon(suggestion.types),
            color: AppColors.primaryDark,
            size: 20,
          ),
        ),
        title: Text(
          suggestion.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          suggestion.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        trailing: isResolving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : distance.isNotEmpty
            ? Text(
                distance,
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
        onTap: isResolving ? null : onTap,
      ),
    );
  }

  IconData _suggestionIcon(List<String> types) {
    if (types.contains('shopping_mall')) return Icons.shopping_bag_outlined;
    if (types.contains('university') || types.contains('school')) {
      return Icons.school_outlined;
    }
    if (types.contains('hospital') || types.contains('doctor')) {
      return Icons.local_hospital_outlined;
    }
    if (types.contains('bus_station') ||
        types.contains('transit_station') ||
        types.contains('train_station')) {
      return Icons.directions_bus_outlined;
    }
    if (types.contains('airport')) return Icons.flight_outlined;
    if (types.contains('restaurant') || types.contains('cafe')) {
      return Icons.restaurant_outlined;
    }
    if (types.contains('lodging')) return Icons.hotel_outlined;
    if (types.contains('saved_place')) return Icons.bookmark_outline;
    return Icons.location_on_outlined;
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 6),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyles.caption.copyWith(color: color, fontSize: 10),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.textDisabled),
            const SizedBox(height: AppSizes.sm),
            Text(title, textAlign: TextAlign.center, style: TextStyles.title),
            const SizedBox(height: AppSizes.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSizes.sm),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
