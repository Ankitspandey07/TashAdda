import 'card.dart';

/// How a player is currently betting in Teen Patti.
///
/// A player starts [blind] (has not looked at their cards) and may switch to
/// [seen] after looking. This affects the minimum stake (seen players post
/// double the current blind stake).
enum BettingMode { blind, seen }

/// A seated participant.
///
/// The player's [hand] is private: the networking layer must only ever send a
/// player their own cards (see the security protocol in the spec). This model
/// keeps the hand here so the authoritative host can hold it, but transport
/// code should never serialize another player's [hand].
class Player {
  Player({
    required this.id,
    required this.name,
    required this.seat,
    this.chips = 0,
  });

  /// Stable unique id (connection/account id).
  final String id;
  final String name;

  /// Seat index at the table (0-based).
  final int seat;

  /// Remaining chip balance.
  int chips;

  /// The player's private cards for the current round.
  final List<PlayingCard> hand = [];

  BettingMode bettingMode = BettingMode.blind;

  /// `true` once the player folds out of the current round.
  bool hasFolded = false;

  /// Total chips this player has committed to the pot this round.
  int currentBet = 0;

  bool get isBlind => bettingMode == BettingMode.blind;
  bool get isSeen => bettingMode == BettingMode.seen;

  /// Marks the player as having looked at their cards.
  void see() => bettingMode = BettingMode.seen;

  /// Clears per-round state so the player can be reused next round.
  void resetForNewRound() {
    hand.clear();
    bettingMode = BettingMode.blind;
    hasFolded = false;
    currentBet = 0;
  }

  @override
  String toString() => 'Player($id, seat=$seat, chips=$chips)';
}
