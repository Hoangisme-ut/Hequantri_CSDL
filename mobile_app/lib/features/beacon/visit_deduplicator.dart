class VisitReservation {
  const VisitReservation._(this.artifactId, this.sequence);

  final String artifactId;
  final int sequence;
}

/// Mirrors the backend's per-user, per-artifact 300-second visit window.
class VisitDeduplicator {
  VisitDeduplicator({
    required this.clock,
    this.window = const Duration(seconds: 300),
  });

  final DateTime Function() clock;
  final Duration window;
  final Map<String, DateTime> _recordedAt = {};
  final Map<String, VisitReservation> _pending = {};
  int _sequence = 0;

  /// Clears the page-local window when the authenticated session changes.
  void reset() {
    _recordedAt.clear();
    _pending.clear();
  }

  VisitReservation? reserve(String artifactId) {
    if (_pending.containsKey(artifactId)) return null;
    final previous = _recordedAt[artifactId];
    if (previous != null && clock().difference(previous) <= window) {
      return null;
    }

    final reservation = VisitReservation._(artifactId, ++_sequence);
    _pending[artifactId] = reservation;
    return reservation;
  }

  void complete(
    VisitReservation reservation, {
    required bool succeeded,
    DateTime? visitedAt,
    bool wasCreated = false,
  }) {
    if (!identical(_pending[reservation.artifactId], reservation)) return;
    _pending.remove(reservation.artifactId);
    if (!succeeded) return;

    if (visitedAt != null) {
      _recordedAt[reservation.artifactId] = visitedAt;
    } else if (wasCreated) {
      // Older backend records may omit visited_at. Use the local clock only
      // for a confirmed new record; an existing 200 response has no safe
      // local substitute for the original visit time.
      _recordedAt[reservation.artifactId] = clock();
    } else {
      _recordedAt.remove(reservation.artifactId);
    }
  }
}
