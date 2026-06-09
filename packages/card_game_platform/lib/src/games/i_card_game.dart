import '../models/card.dart';
import '../models/deck.dart';
import 'hand_result.dart';

/// Pairs a player id with the hand they showed at showdown.
class ShowdownEntry {
  const ShowdownEntry(this.playerId, this.cards);
  final String playerId;
  final List<PlayingCard> cards;
}

/// The plug-in contract every game in the catalog implements.
///
/// The lobby, networking, and state-machine layers depend only on this
/// interface, so new games (Rummy, Poker, Blackjack, ...) can be added without
/// touching the transport code. Implementations must be pure with respect to
/// evaluation: no shared mutable state, so the authoritative host can evaluate
/// hands deterministically.
abstract interface class ICardGame {
  /// Stable identifier used in lobby/room metadata, e.g. `teen_patti`.
  String get id;

  /// Display name, e.g. `Teen Patti`.
  String get name;

  /// Inclusive seat limits for a single table.
  int get minPlayers;
  int get maxPlayers;

  /// Cards dealt to each player per round.
  int get cardsPerPlayer;

  /// Builds the deck sized for [playerCount] (handles 52 vs 104 scaling).
  Deck buildDeck(int playerCount);

  /// Evaluates a single hand into a comparable [HandResult].
  HandResult evaluate(List<PlayingCard> cards);

  /// Convenience comparator: positive if [a] beats [b], 0 if tied.
  int compare(List<PlayingCard> a, List<PlayingCard> b) =>
      evaluate(a).compareTo(evaluate(b));

  /// Returns the id(s) of the winning player(s). More than one id means a tie
  /// (split pot), which double-deck play can produce.
  List<String> determineWinners(List<ShowdownEntry> entries) {
    if (entries.isEmpty) return const [];
    HandResult? best;
    final winners = <String>[];
    for (final entry in entries) {
      final result = evaluate(entry.cards);
      if (best == null || result.beats(best)) {
        best = result;
        winners
          ..clear()
          ..add(entry.playerId);
      } else if (result.tiesWith(best)) {
        winners.add(entry.playerId);
      }
    }
    return winners;
  }
}
