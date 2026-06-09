import 'package:card_game_platform/card_game_platform.dart';
import 'package:test/test.dart';

void main() {
  const game = TeenPattiGame();

  GameState newTable() => GameState(roomId: 'r1', game: game);

  void seat(GameState s, int n) {
    for (var i = 0; i < n; i++) {
      s.addPlayer(Player(id: 'p$i', name: 'P$i', seat: i, chips: 1000));
    }
  }

  group('Seat constraints', () {
    test('cannot exceed max players (5)', () {
      final s = newTable();
      seat(s, 5);
      expect(s.isFull, isTrue);
      expect(() => s.addPlayer(Player(id: 'x', name: 'X', seat: 5)),
          throwsStateError);
    });

    test('cannot reuse a seat', () {
      final s = newTable();
      s.addPlayer(Player(id: 'a', name: 'A', seat: 0));
      expect(() => s.addPlayer(Player(id: 'b', name: 'B', seat: 0)),
          throwsStateError);
    });
  });

  group('State machine', () {
    test('rejects illegal transition', () {
      final s = newTable();
      expect(() => s.transitionTo(GamePhase.showdown), throwsStateError);
    });

    test('allows the legal happy path', () {
      final s = newTable();
      s.transitionTo(GamePhase.shufflingAndDealing);
      s.transitionTo(GamePhase.playerTurnActive);
      s.transitionTo(GamePhase.showdown);
      s.transitionTo(GamePhase.payoutCalculation);
      s.transitionTo(GamePhase.lobbyWaiting);
      expect(s.phase, GamePhase.lobbyWaiting);
    });
  });

  group('Round start', () {
    test('refuses to start below minimum players', () {
      final s = newTable();
      seat(s, 2);
      expect(s.startRound, throwsStateError);
    });

    test('deals 3 cards to each of 4 players and goes to player turn', () {
      final s = newTable();
      seat(s, 4);
      s.startRound();
      expect(s.phase, GamePhase.playerTurnActive);
      for (final p in s.players) {
        expect(p.hand.length, 3);
      }
      // 52 - 12 dealt = 40 remaining.
      expect(s.deck!.remaining, 40);
    });
  });
}
