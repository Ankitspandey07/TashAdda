import '../engine/game_engine.dart';
import '../score/scoreboard.dart';
import 'table_view.dart';
import 'view_codec.dart';

/// Drives the table from a local [GameEngine] for a chosen viewer seat.
///
/// Used both for single-device play (viewer = the human, others are bots) and,
/// later, as the host's own view of a networked game. It also exposes
/// [redactedSeatsFor]/[handFor] helpers the network host reuses so every client
/// only ever receives its own cards.
class LocalController extends TableController {
  LocalController(
    this.engine, {
    required this.viewerSeatId,
    required this.title,
    this.isHost = false,
    this.onCloseRoom,
  }) {
    engine.addListener(_onEngineChanged);
  }

  final GameEngine engine;
  final String viewerSeatId;
  @override
  final String title;
  final bool isHost;
  final void Function()? onCloseRoom;

  void _onEngineChanged() => notifyListeners();

  Seat get _viewer =>
      engine.seats.firstWhere((s) => s.id == viewerSeatId);

  bool get _myTurn =>
      engine.isBettingPhase &&
      engine.phase != RoundPhase.sideshowPending &&
      engine.current.id == viewerSeatId;

  @override
  TableView get view => buildTableView(engine, viewerSeatId);

  @override
  bool get canCloseRoom => isHost;

  @override
  void closeRoom() => onCloseRoom?.call();

  @override
  SessionSummary? get sessionSummary {
    if (engine.scoreboard.roundsPlayed == 0) return null;
    return engine.scoreboard.buildSummary([
      for (final s in engine.seats) (id: s.id, name: s.name),
    ]);
  }

  @override
  void see() {
    if (_myTurn || engine.isBettingPhase) engine.see(_viewer);
  }

  @override
  void call() {
    if (_myTurn) engine.bet(_viewer, raise: false);
  }

  @override
  void raise() {
    if (_myTurn) engine.bet(_viewer, raise: true);
  }

  @override
  void fold() {
    if (_myTurn) engine.fold(_viewer);
  }

  @override
  void show() {
    if (_myTurn) engine.show(_viewer);
  }

  @override
  void requestSideshow(String targetId) {
    if (_myTurn) engine.requestSideshow(_viewer, targetId);
  }

  @override
  void respondSideshow(bool accept) {
    engine.respondSideshow(_viewer, accept);
  }

  @override
  void leaveTable() => engine.markExited(_viewer);

  @override
  void nextRound() {
    if (engine.phase == RoundPhase.roundOver) engine.startRound();
  }

  @override
  void dispose() {
    engine.removeListener(_onEngineChanged);
    super.dispose();
  }
}
