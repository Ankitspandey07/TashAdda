/// A game-agnostic, comparable result of evaluating a player's hand.
///
/// Comparison is lexicographic: first by [category] (higher = stronger), then by
/// the [tieBreakers] list element-by-element (higher = stronger). Two results
/// that compare equal represent a genuine tie — which the double-deck rules make
/// possible — and callers should split the pot among all tied players.
class HandResult implements Comparable<HandResult> {
  const HandResult({
    required this.category,
    required this.categoryName,
    required this.tieBreakers,
  });

  /// Strength of the hand category (higher beats lower). Each game defines its
  /// own scale; Teen Patti uses 1 (high card) .. 6 (trail).
  final int category;

  /// Human-readable category label, e.g. `Pure Sequence`.
  final String categoryName;

  /// Ordered, descending-significance tie-break values used only when two hands
  /// share the same [category].
  final List<int> tieBreakers;

  @override
  int compareTo(HandResult other) {
    if (category != other.category) {
      return category.compareTo(other.category);
    }
    final len =
        tieBreakers.length < other.tieBreakers.length
            ? tieBreakers.length
            : other.tieBreakers.length;
    for (var i = 0; i < len; i++) {
      final c = tieBreakers[i].compareTo(other.tieBreakers[i]);
      if (c != 0) return c;
    }
    return tieBreakers.length.compareTo(other.tieBreakers.length);
  }

  bool beats(HandResult other) => compareTo(other) > 0;
  bool tiesWith(HandResult other) => compareTo(other) == 0;

  @override
  String toString() => '$categoryName${tieBreakers.isEmpty ? '' : ' $tieBreakers'}';
}
