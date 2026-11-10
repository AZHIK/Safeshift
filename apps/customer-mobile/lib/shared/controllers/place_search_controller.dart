// The public constructor deliberately maps friendly parameter names to private
// fields; initializing formals would expose private names to callers.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/place_suggestion.dart';
import '../models/ride_place.dart';
import '../models/user_location.dart';
import '../repositories/places_repository.dart';
import '../services/places_api.dart';
import '../utils/geo.dart';

/// Ephemeral, per-sheet autocomplete state.
///
/// A controller instance is created for each pickup/delivery sheet, so the two
/// selections never share a query, session token, or resolving state.
class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController({
    required PlacesRepository repository,
    String? profileId,
    GeoPoint? reference,
    bool worldwide = false,
    String language = 'en',
    Duration debounceDuration = const Duration(milliseconds: 350),
  }) : _repository = repository,
       _profileId = profileId,
       _reference = reference,
       _worldwide = worldwide,
       _language = language,
       _debounceDuration = debounceDuration {
    unawaited(_loadSavedPlaces());
  }

  final PlacesRepository _repository;
  final String? _profileId;
  final String _language;
  final Duration _debounceDuration;

  String _query = '';
  List<PlaceSuggestion> _suggestions = const <PlaceSuggestion>[];
  List<RidePlace> _savedPlaces = const <RidePlace>[];
  bool _isSearching = false;
  bool _isLoadingSaved = false;
  String? _errorMessage;
  String? _savedErrorMessage;
  bool _usingFallback = false;
  String? _resolvingPlaceId;
  bool _isResolvingCurrentLocation = false;
  String _sessionToken = _newSessionToken();
  int _requestGeneration = 0;
  Timer? _debounce;
  CancelToken? _cancelToken;
  GeoPoint? _reference;
  bool _worldwide;
  bool _hasSearched = false;
  bool _disposed = false;

  String get query => _query;
  List<PlaceSuggestion> get suggestions => _suggestions;
  List<RidePlace> get savedPlaces => _savedPlaces;
  bool get isSearching => _isSearching;
  bool get isLoadingSaved => _isLoadingSaved;
  String? get errorMessage => _errorMessage;
  String? get savedErrorMessage => _savedErrorMessage;
  bool get usingFallback => _usingFallback;
  String? get resolvingPlaceId => _resolvingPlaceId;
  bool get isResolvingCurrentLocation => _isResolvingCurrentLocation;
  bool get hasSearched => _hasSearched;
  bool get worldwide => _worldwide;
  GeoPoint? get reference => _reference;
  bool get isProviderConfigured => _repository.isProviderConfigured;
  bool get hasQuery => _query.trim().length >= 2;
  String get sessionToken => _sessionToken;

  List<PlaceSuggestion> get savedSuggestions {
    return _savedPlaces
        .map((place) => PlaceSuggestion.fromRidePlace(place))
        .toList(growable: false);
  }

  /// Updates the geographic reference used for proximity ranking. The
  /// reference is never treated as the selected pickup/delivery point.
  void setReference(GeoPoint? reference) {
    final same =
        _reference?.latitude == reference?.latitude &&
        _reference?.longitude == reference?.longitude;
    if (same) return;
    _reference = reference;
    if (hasQuery) _scheduleSearch(immediate: true);
  }

  void setWorldwide(bool value) {
    if (_worldwide == value) return;
    _worldwide = value;
    if (hasQuery) {
      _scheduleSearch(immediate: true);
    } else {
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    _scheduleSearch();
  }

  Future<void> retry() async {
    final normalized = _query.trim();
    if (normalized.length < 2) {
      _errorMessage = null;
      _usingFallback = false;
      _isSearching = false;
      notifyListeners();
      await _loadSavedPlaces();
      return;
    }
    _cancelPending();
    final generation = ++_requestGeneration;
    _errorMessage = null;
    _isSearching = true;
    _suggestions = const <PlaceSuggestion>[];
    notifyListeners();
    await _search(normalized, generation);
  }

  /// Resolves a tapped suggestion into a verified place.
  ///
  /// Raw search text is never returned as a location: provider suggestions
  /// must pass through Place Details, while saved/catalog suggestions already
  /// carry coordinates.
  Future<RidePlace?> selectSuggestion(PlaceSuggestion suggestion) async {
    if (_resolvingPlaceId != null) return null;

    final resolved = suggestion.resolvedPlace;
    if (resolved != null) return resolved;

    if (!suggestion.hasPlaceId) {
      _errorMessage = 'That place could not be identified. Try another result.';
      notifyListeners();
      return null;
    }

    _resolvingPlaceId = suggestion.placeId;
    _errorMessage = null;
    notifyListeners();

    try {
      final place = await _repository.getPlaceDetails(
        placeId: suggestion.placeId,
        sessionToken: _sessionToken,
        fallbackName: suggestion.title,
        language: _language,
      );
      if (_disposed) return place;
      // A new token starts the next autocomplete/details session.
      _sessionToken = _newSessionToken();
      _resolvingPlaceId = null;
      notifyListeners();
      return place;
    } on PlacesApiException catch (error) {
      if (_disposed) return null;
      _resolvingPlaceId = null;
      if (!error.isCancellation) _errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      if (_disposed) return null;
      _resolvingPlaceId = null;
      _errorMessage = 'That place could not be resolved. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Resolves the customer's GPS fix into a readable address while preserving
  /// the exact coordinates and accuracy metadata.
  Future<RidePlace?> resolveCurrentLocation(UserLocation location) async {
    if (_isResolvingCurrentLocation) return null;

    _isResolvingCurrentLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final place = await _repository.reverseGeocode(
        latitude: location.latitude,
        longitude: location.longitude,
        source: RidePlaceSource.gps,
        language: _language,
      );
      if (_disposed) return place;
      _isResolvingCurrentLocation = false;
      notifyListeners();
      return place.copyWith(
        source: RidePlaceSource.gps,
        accuracyMeters: location.accuracyMeters,
        capturedAt: location.timestamp,
      );
    } on PlacesApiException catch (error) {
      if (_disposed) return null;
      _isResolvingCurrentLocation = false;
      _errorMessage = error.type == PlacesErrorType.cancelled
          ? null
          : 'Address lookup failed; using your GPS coordinates.';
      notifyListeners();
      return _gpsFallback(location);
    } catch (_) {
      if (_disposed) return null;
      _isResolvingCurrentLocation = false;
      _errorMessage = 'Address lookup failed; using your GPS coordinates.';
      notifyListeners();
      return _gpsFallback(location);
    }
  }

  void _scheduleSearch({bool immediate = false}) {
    final normalized = _query.trim();
    _cancelPending();
    final generation = ++_requestGeneration;
    _errorMessage = null;
    _usingFallback = false;

    if (normalized.length < 2) {
      _suggestions = const <PlaceSuggestion>[];
      _isSearching = false;
      _hasSearched = false;
      notifyListeners();
      return;
    }

    _hasSearched = true;
    _isSearching = true;
    // Clear the previous query's rows so a slow network cannot present stale
    // results as if they belong to the current query.
    _suggestions = const <PlaceSuggestion>[];
    notifyListeners();

    if (immediate) {
      unawaited(_search(normalized, generation));
    } else {
      _debounce = Timer(
        _debounceDuration,
        () => unawaited(_search(normalized, generation)),
      );
    }
  }

  Future<void> _search(String query, int generation) async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      final providerResults = await _repository.autocompletePlaces(
        query: query,
        sessionToken: _sessionToken,
        origin: _reference,
        worldwide: _worldwide,
        language: _language,
        cancelToken: cancelToken,
      );
      if (_disposed || generation != _requestGeneration) return;

      _suggestions = _mergeSavedMatches(query, providerResults);
      _isSearching = false;
      _usingFallback = false;
      _errorMessage = null;
      notifyListeners();
    } on PlacesApiException catch (error) {
      if (_disposed || generation != _requestGeneration) return;
      if (error.isCancellation) return;
      await _handleProviderFailure(error, query, generation);
    } catch (_) {
      if (_disposed || generation != _requestGeneration) return;
      _isSearching = false;
      _suggestions = _savedSuggestionsMatching(query);
      _errorMessage = 'Something went wrong while searching. Please try again.';
      notifyListeners();
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  Future<void> _handleProviderFailure(
    PlacesApiException error,
    String query,
    int generation,
  ) async {
    final savedMatches = _savedSuggestionsMatching(query);

    // A missing/rejected client key should not break place selection. Fall
    // back to the SafeShift address/neighborhood directory when possible.
    if (error.isConfigurationError && _profileId != null) {
      try {
        final directory = await _repository.searchPlaces(_profileId, query);
        if (_disposed || generation != _requestGeneration) return;
        final directorySuggestions = directory
            .map((place) => PlaceSuggestion.fromRidePlace(place))
            .toList(growable: false);
        final hasResults =
            directorySuggestions.isNotEmpty || savedMatches.isNotEmpty;
        _suggestions = _dedupeResolved(<PlaceSuggestion>[
          ...savedMatches,
          ...directorySuggestions,
        ]);
        _usingFallback = hasResults;
        _isSearching = false;
        _errorMessage = hasResults ? null : error.message;
        notifyListeners();
        return;
      } catch (_) {
        // Fall through to the provider error.
      }
    }

    if (_disposed || generation != _requestGeneration) return;
    _suggestions = savedMatches;
    _isSearching = false;
    _usingFallback = false;
    _errorMessage = error.message;
    notifyListeners();
  }

  Future<void> _loadSavedPlaces() async {
    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) return;

    _isLoadingSaved = true;
    _savedErrorMessage = null;
    notifyListeners();

    try {
      final places = await _repository.getSavedPlaces(profileId);
      if (_disposed) return;
      _savedPlaces = places;
    } catch (_) {
      if (_disposed) return;
      _savedErrorMessage = 'Saved places could not be loaded.';
    } finally {
      if (!_disposed) {
        _isLoadingSaved = false;
        notifyListeners();
      }
    }
  }

  List<PlaceSuggestion> _mergeSavedMatches(
    String query,
    List<PlaceSuggestion> providerResults,
  ) {
    final savedMatches = _savedSuggestionsMatching(query);
    if (savedMatches.isEmpty) return providerResults;
    return _dedupeResolved(<PlaceSuggestion>[
      ...savedMatches,
      ...providerResults,
    ]);
  }

  List<PlaceSuggestion> _savedSuggestionsMatching(String query) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return const <PlaceSuggestion>[];

    final matches = _savedPlaces.where((place) {
      final haystack =
          '${place.name} ${place.label ?? ''} ${place.district} '
                  '${place.addressLine}'
              .toLowerCase();
      return tokens.every((token) => haystack.contains(token));
    });

    return matches
        .map((place) => PlaceSuggestion.fromRidePlace(place))
        .toList(growable: false);
  }

  List<PlaceSuggestion> _dedupeResolved(List<PlaceSuggestion> input) {
    final seenIds = <String>{};
    final seenText = <String>{};
    final output = <PlaceSuggestion>[];
    for (final suggestion in input) {
      final id = suggestion.placeId.trim();
      if (id.isNotEmpty && !seenIds.add(id)) continue;
      final text = '${suggestion.title}|${suggestion.subtitle}'
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (!seenText.add(text)) continue;
      output.add(suggestion);
      if (output.length >= 10) break;
    }
    return output;
  }

  RidePlace _gpsFallback(UserLocation location) {
    return RidePlace(
      id:
          'gps:${location.latitude.toStringAsFixed(6)},'
          '${location.longitude.toStringAsFixed(6)}',
      name: 'Current location',
      district: 'GPS coordinates',
      latitude: location.latitude,
      longitude: location.longitude,
      source: RidePlaceSource.gps,
      accuracyMeters: location.accuracyMeters,
      capturedAt: location.timestamp,
      formattedAddress:
          '${location.latitude.toStringAsFixed(5)}, '
          '${location.longitude.toStringAsFixed(5)}',
    );
  }

  void _cancelPending() {
    _debounce?.cancel();
    _debounce = null;
    _cancelToken?.cancel('superseded');
    _cancelToken = null;
  }

  static String _newSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPending();
    super.dispose();
  }
}
