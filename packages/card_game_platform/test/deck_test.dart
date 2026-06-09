import 'dart:math';

import 'package:card_game_platform/card_game_platform.dart';
import 'package:test/test.dart';

void main() {
  group('Deck scaling', () {
    test('3-5 players use a single 52-card deck', () {
      for (final n in [3, 4, 5]) {
        final deck = Deck.forPlayers(n);
        expect(deck.remaining, 52, reason: '$n players');
        expect(deck.isDoubleDeck, isFalse);
      }
    });

    test('more than 5 players use a 104-card double deck', () {
      for (final n in [6, 7, 8]) {
        final deck = Deck.forPlayers(n);
        expect(deck.remaining, 104, reason: '$n players');
        expect(deck.isDoubleDeck, isTrue);
      }
    });

    test('rejects non-positive player counts', () {
      expect(() => Deck.forPlayers(0), throwsArgumentError);
      expect(() => Deck.forPlayers(-1), throwsArgumentError);
    });

    test('single deck has 52 distinct cards, no jokers', () {
      final deck = Deck.standard();
      final faces = deck.cards.map((c) => c.code).toSet();
      expect(faces.length, 52);
    });

    test('double deck has each face exactly twice, kept distinct', () {
      final deck = Deck.standard(deckCount: 2);
      expect(deck.remaining, 104);
      // Distinct objects (deckIndex differentiates copies).
      expect(deck.cards.toSet().length, 104);
      // Only 52 distinct faces.
      expect(deck.cards.map((c) => c.code).toSet().length, 52);
    });
  });

  group('Deck dealing', () {
    test('deal removes from the top and reduces remaining', () {
      final deck = Deck.standard();
      final dealt = deck.deal(3);
      expect(dealt.length, 3);
      expect(deck.remaining, 49);
    });

    test('throws when dealing more than remaining', () {
      final deck = Deck.standard();
      expect(() => deck.deal(53), throwsStateError);
    });

    test('shuffle with a seed is deterministic', () {
      final a = Deck.standard()..shuffle(Random(42));
      final b = Deck.standard()..shuffle(Random(42));
      expect(a.cards.map((c) => c.toString()).toList(),
          b.cards.map((c) => c.toString()).toList());
    });
  });
}
