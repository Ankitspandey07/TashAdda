import '../games/i_card_game.dart';
import 'deck.dart';
import 'player.dart';

/// Authoritative round phases. The host/server is the only authority allowed to
/// advance phases; clients render whatever phase they are told they are in.
///
/// Flow: lobbyWaiting -> shufflingAndDealing -> playerTurnActive ->
/// sideShowEvaluation -> showdown -> payoutCalculation -> (back to lobby).
enum GamePhase {
  lobbyWaiting,
  shufflingAndDealing,
  playerTurnActive,
  sideShowEvaluation,
  showdown,
  payoutCalculation,
}

/// Allowed forward transitions for the round state machine. Used to reject
/// illegal phase jumps (anti-cheat / desync protection).
const Map<GamePhase, Set<GamePhase>> _allowedTransitions = {
  GamePhase.lobbyWaiting: {GamePhase.shufflingAndDealing},
  GamePhase.shufflingAndDealing: {GamePhase.playerTurnActive},
  GamePhase.playerTurnActive: {
    GamePhase.playerTurnActive,
    GamePhase.sideShowEvaluation,
    GamePhase.showdown,
  },
  GamePhase.sideShowEvaluation: {
    GamePhase.playerTurnActive,
    GamePhase.showdown,
  },
  GamePhase.showdown: {GamePhase.payoutCalculation},
  GamePhase.payoutCalculation: {GamePhase.lobbyWaiting},
};

/// Holds the authoritative state of one table for one game.
///
/// This is intentionally minimal for Phase 1 (models + scaling). Betting amounts
/// and turn-timer logic are layered on in later phases; what matters here is the
/// guarded [GamePhase] machine, seat constraints, and deck scaling.
class GameState {
  GameState({
    required this.roomId,
    required this.game,
  }) : phase = GamePhase.lobbyWaiting;

  final String roomId;
  final ICardGame game;

  final List<Player> players = [];
  GamePhase phase;
  Deck? deck;
  int pot = 0;

  /// Seat index whose turn it is during [GamePhase.playerTurnActive].
  int? activeSeat;

  int get playerCount => players.length;

  /// Players still in the round (not folded).
  List<Player> get activePlayers =>
      players.where((p) => !p.hasFolded).toList(growable: false);

  /// Whether the table is full for this game.
  bool get isFull => players.length >= game.maxPlayers;

  /// Adds a player to the table while in the lobby. Throws if full, if the game
  /// is already running, or if the seat is taken.
  void addPlayer(Player player) {
    if (phase != GamePhase.lobbyWaiting) {
      throw StateError('Players can only join during lobbyWaiting');
    }
    if (isFull) {
      throw StateError('Table is full (max ${game.maxPlayers})');
    }
    if (players.any((p) => p.seat == player.seat)) {
      throw StateError('Seat ${player.seat} is already taken');
    }
    players.add(player);
  }

  /// Validates and applies a phase transition. Throws [StateError] on an
  /// illegal jump so cheating/desync attempts fail loudly.
  void transitionTo(GamePhase next) {
    final allowed = _allowedTransitions[phase] ?? const <GamePhase>{};
    if (!allowed.contains(next)) {
      throw StateError('Illegal transition: $phase -> $next');
    }
    phase = next;
  }

  /// Begins a round: enforces seat count, builds/scales and shuffles the deck,
  /// deals private hands, and advances the machine. Returns nothing; hands live
  /// on each [Player].
  void startRound([Deck? customDeck]) {
    if (players.length < game.minPlayers) {
      throw StateError(
          'Need at least ${game.minPlayers} players, have ${players.length}');
    }
    transitionTo(GamePhase.shufflingAndDealing);
    final d = customDeck ?? game.buildDeck(players.length)
      ..shuffle();
    deck = d;
    for (final p in players) {
      p.resetForNewRound();
    }
    for (var i = 0; i < game.cardsPerPlayer; i++) {
      for (final p in players) {
        p.hand.addAll(d.deal(1));
      }
    }
    activeSeat = players.first.seat;
    transitionTo(GamePhase.playerTurnActive);
  }
}
