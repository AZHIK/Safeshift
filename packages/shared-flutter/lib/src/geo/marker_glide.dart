import 'package:flutter/animation.dart';

import 'route_geometry.dart';

/// Moves a map marker smoothly between GPS fixes, the way Bolt and Uber cars
/// slide along the road instead of jumping every few seconds.
///
/// Call [update] with each new fix. The marker travels from where it is now
/// to the new point over roughly the time between fixes, turning to the
/// direction of travel along the way. [onFrame] fires about 15 times a
/// second while moving; rebuild the map's markers from [position] and
/// [bearing] there.
class MarkerGlide {
  MarkerGlide({
    required TickerProvider vsync,
    required this.onFrame,
    this.maxFrameRate = 15,
    this.teleportMeters = 1500,
  }) : _controller = AnimationController(vsync: vsync) {
    _controller.addListener(_tick);
  }

  final VoidCallback onFrame;
  final int maxFrameRate;

  /// Jumps larger than this are placed instantly, not animated.
  final double teleportMeters;

  final AnimationController _controller;
  GeoPoint? _position;
  double _bearing = 0;
  GeoPoint? _from;
  GeoPoint? _to;
  double _fromBearing = 0;
  double _toBearing = 0;
  DateTime? _lastFixAt;
  int _lastFrameMs = 0;

  /// Where the marker should be drawn now, or null when there is no fix.
  GeoPoint? get position => _position;

  /// Direction the vehicle faces, 0–360 (0 = north).
  double get bearing => _bearing;

  /// Feeds a new fix. [heading] is the device's direction of travel when
  /// known; otherwise the bearing is derived from the movement.
  void update(GeoPoint target, {double? heading, bool animate = true}) {
    final start = _position;
    final now = DateTime.now();
    final moved = start == null ? 0.0 : distanceMeters(start, target);
    final nextBearing =
        heading ??
        (start != null && moved > 3 ? bearingDegrees(start, target) : null);

    if (!animate || start == null || moved > teleportMeters) {
      _controller.stop();
      _position = _to = target;
      _bearing = _toBearing = nextBearing ?? _bearing;
      _lastFixAt = now;
      onFrame();
      return;
    }

    _from = start;
    _to = target;
    _fromBearing = _bearing;
    _toBearing = nextBearing ?? _bearing;
    final gapMs = _lastFixAt == null
        ? 3000
        : now.difference(_lastFixAt!).inMilliseconds;
    _lastFixAt = now;
    // Spread the movement over about the time the next fix will take, so the
    // marker is still moving when it arrives instead of stopping and waiting.
    _controller.duration = Duration(milliseconds: gapMs.clamp(600, 4500));
    _lastFrameMs = -1000;
    _controller.forward(from: 0);
  }

  /// Removes the marker (no position).
  void clear() {
    _controller.stop();
    _position = _from = _to = null;
    _lastFixAt = null;
    onFrame();
  }

  void _tick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = _controller.value;
    _position = lerpPoint(from, to, t);
    _bearing = lerpBearing(_fromBearing, _toBearing, t);
    // Throttle on the animation's own clock (vsync), not wall time.
    final elapsedMs = _controller.lastElapsedDuration?.inMilliseconds ?? 0;
    if (elapsedMs - _lastFrameMs >= 1000 ~/ maxFrameRate ||
        _controller.isCompleted) {
      _lastFrameMs = elapsedMs;
      onFrame();
    }
  }

  void dispose() => _controller.dispose();
}
