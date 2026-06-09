import 'dart:math';

import 'card.dart';

/// A draw pile of [PlayingCard]s.
///
/// The deck scales automatically with the table/session size per the platform
/// rule: up to 5 players use a single 52-card deck; more than 5 players switch
/// to a double deck (104 cards). Jokers are never included.
class Deck {
  Deck._(this._cards);

  /// Number of players above which the game switches to a double deck.
  static const int singleDeckMaxPlayers = 5;

  final List<PlayingCard> _cards;

  /// Cards remaining in the draw pile, top of the pile last.
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  int get remaining => _cards.length;

  /// Builds a fresh, ordered deck sized for [playerCount].
  ///
  /// `playerCount <= 5` -> 52 cards (1 deck). `playerCount > 5` -> 104 cards
  /// (2 decks). Throws [ArgumentError] for non-positive counts.
  factory Deck.forPlayers(int playerCount) {
    if (playerCount <= 0) {
      throw ArgumentError.value(
          playerCount, 'playerCount', 'must be a positive number of players');
    }
    final deckCount = playerCount <= singleDeckMaxPlayers ? 1 : 2;
    return Deck.standard(deckCount: deckCount);
  }

  /// Builds [deckCount] full 52-card decks combined into one pile.
  factory Deck.standard({int deckCount = 1}) {
    if (deckCount < 1) {
      throw ArgumentError.value(deckCount, 'deckCount', 'must be >= 1');
    }
    final cards = <PlayingCard>[];
    for (var d = 0; d < deckCount; d++) {
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          cards.add(PlayingCard(rank, suit, deckIndex: d));
        }
      }
    }
    return Deck._(cards);
  }

  /// Whether this deck currently holds double-deck (104+) cards. Tie-breaking
  /// logic uses this to know identical face values are possible.
  bool get isDoubleDeck => _cards.length > 52;

  /// Shuffles in place. Pass a seeded [Random] for deterministic tests.
  void shuffle([Random? random]) => _cards.shuffle(random);

  /// Removes and returns the top [count] cards. Throws [StateError] if the deck
  /// does not have enough cards left.
  List<PlayingCard> deal(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    if (count > _cards.length) {
      throw StateError(
          'Cannot deal $count cards: only ${_cards.length} remaining');
    }
    final dealt = _cards.sublist(_cards.length - count);
    _cards.removeRange(_cards.length - count, _cards.length);
    return dealt;
  }
}
