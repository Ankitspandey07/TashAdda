/// The four standard suits. Order has no bearing on hand strength in Teen Patti
/// (suits are not used as a tie-breaker), but it gives cards a stable identity.
enum Suit {
  spades('S'),
  hearts('H'),
  diamonds('D'),
  clubs('C');

  const Suit(this.symbol);

  /// Single-character symbol, handy for compact wire/log formats.
  final String symbol;
}

/// Card ranks with their comparison value. Ace is high (14) by default; the
/// special low-ace run (A-2-3) is handled inside the hand evaluator, not here.
enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, 'T'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.symbol);

  /// Numeric strength used for comparisons (2..14, ace high).
  final int value;

  /// Single-character symbol (T = ten) for compact formats.
  final String symbol;
}

/// A single playing card.
///
/// In double-deck mode (>5 players) two physically distinct cards can share the
/// same [rank] and [suit]. [deckIndex] (0 for the first deck, 1 for the second)
/// keeps those two copies distinct so a deck can never accidentally collapse
/// duplicates. Hand strength deliberately ignores [deckIndex]: two identical
/// face values are equal for tie-breaking, which is the whole point of the
/// double-deck rule.
class PlayingCard {
  const PlayingCard(this.rank, this.suit, {this.deckIndex = 0});

  final Rank rank;
  final Suit suit;
  final int deckIndex;

  /// `true` when two cards have the same face (rank + suit), regardless of which
  /// physical deck they came from.
  bool sameFace(PlayingCard other) =>
      rank == other.rank && suit == other.suit;

  /// Compact code such as `AS`, `TD`, `2C`.
  String get code => '${rank.symbol}${suit.symbol}';

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.rank == rank &&
      other.suit == suit &&
      other.deckIndex == deckIndex;

  @override
  int get hashCode => Object.hash(rank, suit, deckIndex);

  @override
  String toString() => deckIndex == 0 ? code : '$code#$deckIndex';
}
