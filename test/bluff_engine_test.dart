import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti_app/engine/bluff_engine.dart';

PlayingCard c(Rank r, Suit s) => PlayingCard(r, s);

BluffEngine twoPlayerCallWindow({
  required List<PlayingCard> played,
  required int rankValue,
  List<PlayingCard> extraPile = const [],
  List<PlayingCard> claimantRemaining = const [],
}) {
  final e = BluffEngine()
    ..addPlayer(BluffPlayer(id: 'p0', name: 'P0'))
    ..addPlayer(BluffPlayer(id: 'p1', name: 'P1', isBot: true));
  e.players[0].hand.addAll(claimantRemaining);
  // Caller holds a card so it isn't mistaken for an emptied winner.
  e.players[1].hand.add(c(Rank.seven, Suit.clubs));
  e.pile
    ..addAll(extraPile)
    ..addAll(played);
  e.requiredRank = rankValue;
  e.turn = 0;
  e.phase = BluffPhase.callWindow;
  e.lastClaim =
      BluffClaim(playerIndex: 0, rankValue: rankValue, cards: played);
  return e;
}

void main() {
  group('Call resolution', () {
    test('caught lie: claimant picks up the whole pile', () {
      final e = twoPlayerCallWindow(
        played: [c(Rank.three, Suit.spades), c(Rank.four, Suit.diamonds)],
        rankValue: 14, // claimed Aces, actually 3 & 4 => lie
        extraPile: [c(Rank.nine, Suit.clubs)],
        claimantRemaining: [c(Rank.king, Suit.hearts)],
      );
      e.debugResolve(1); // P1 calls
      expect(e.pile, isEmpty);
      // Claimant (P0) had 1 card + picks up 3 = 4.
      expect(e.players[0].hand.length, 4);
      expect(e.players[1].hand.length, 1); // keeps its baseline card
      expect(e.phase, BluffPhase.play);
      expect(e.winnerId, isNull);
    });

    test('wrong call on a truthful claim: caller picks up the pile', () {
      final e = twoPlayerCallWindow(
        played: [c(Rank.ace, Suit.spades), c(Rank.ace, Suit.hearts)],
        rankValue: 14, // truthful Aces
        extraPile: [c(Rank.five, Suit.clubs)],
        claimantRemaining: [c(Rank.two, Suit.diamonds)],
      );
      e.debugResolve(1);
      expect(e.pile, isEmpty);
      expect(e.players[1].hand.length, 4); // baseline 1 + picked up A,A,5
      expect(e.players[0].hand.length, 1);
      expect(e.phase, BluffPhase.play);
    });

    test('no challenge and claimant emptied: claimant wins', () {
      final e = twoPlayerCallWindow(
        played: [c(Rank.ace, Suit.spades)],
        rankValue: 14,
        claimantRemaining: const [], // already empty after playing
      );
      e.debugResolve(null);
      expect(e.winnerId, 'p0');
      expect(e.phase, BluffPhase.roundOver);
    });

    test('truthful claim wrongly challenged still wins if claimant is empty', () {
      final e = twoPlayerCallWindow(
        played: [c(Rank.ace, Suit.spades)],
        rankValue: 14, // truthful
        claimantRemaining: const [],
      );
      e.debugResolve(1); // caller loses, but claimant is already empty
      expect(e.winnerId, 'p0');
      expect(e.phase, BluffPhase.roundOver);
    });
  });

  group('Multi-human call window (networked)', () {
    test('only non-claimant humans are pending; bots are not', () {
      final e = BluffEngine()
        ..addPlayer(BluffPlayer(id: 'p0', name: 'P0')) // claimant
        ..addPlayer(BluffPlayer(id: 'p1', name: 'P1')) // human caller
        ..addPlayer(BluffPlayer(id: 'p2', name: 'P2', isBot: true));
      e.players[0].hand.add(c(Rank.king, Suit.spades));
      e.players[1].hand.add(c(Rank.seven, Suit.clubs));
      e.players[2].hand.add(c(Rank.eight, Suit.clubs));
      e.requiredRank = 14; // p0 will claim Aces with a King => lie
      e.turn = 0;
      e.phase = BluffPhase.play;

      e.play([e.players[0].hand.first]);

      expect(e.phase, BluffPhase.callWindow);
      expect(e.mayCall(1), isTrue); // human, non-claimant
      expect(e.mayCall(2), isFalse); // bot is not pending
      expect(e.mayCall(0), isFalse); // claimant cannot call

      e.callBy(1); // caught lie => claimant picks up the pile
      expect(e.phase, BluffPhase.play);
      expect(e.players[0].hand.length, 1);
      expect(e.winnerId, isNull);
    });

    test('passBy removes one human; window stays open for the other', () {
      final e = BluffEngine()
        ..addPlayer(BluffPlayer(id: 'p0', name: 'P0')) // claimant
        ..addPlayer(BluffPlayer(id: 'p1', name: 'P1'))
        ..addPlayer(BluffPlayer(id: 'p2', name: 'P2'));
      e.players[0].hand.add(c(Rank.king, Suit.spades));
      e.players[1].hand.add(c(Rank.seven, Suit.clubs));
      e.players[2].hand.add(c(Rank.eight, Suit.clubs));
      e.requiredRank = 14;
      e.turn = 0;
      e.phase = BluffPhase.play;

      e.play([e.players[0].hand.first]);
      expect(e.mayCall(1), isTrue);
      expect(e.mayCall(2), isTrue);

      e.passBy(1);
      expect(e.phase, BluffPhase.callWindow); // p2 still deciding
      expect(e.mayCall(1), isFalse);
      expect(e.mayCall(2), isTrue);
    });
  });

  test('startGame deals the full 52-card deck across players', () {
    final e = BluffEngine()
      ..addPlayer(BluffPlayer(id: 'you', name: 'You'))
      ..addPlayer(BluffPlayer(id: 'b1', name: 'Bot 1', isBot: true))
      ..addPlayer(BluffPlayer(id: 'b2', name: 'Bot 2', isBot: true))
      ..addPlayer(BluffPlayer(id: 'b3', name: 'Bot 3', isBot: true));
    e.startGame();
    final total = e.players.fold<int>(0, (sum, p) => sum + p.hand.length);
    expect(total, 52);
    expect(e.pile, isEmpty);
    expect(e.phase, BluffPhase.play);
  });
}
