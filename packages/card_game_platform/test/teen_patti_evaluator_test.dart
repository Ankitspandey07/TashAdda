import 'package:card_game_platform/card_game_platform.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  const game = TeenPattiGame();

  HandResult eval(String h) => game.evaluate(hand(h));

  group('Category detection', () {
    test('trail', () {
      expect(eval('AS AH AD').categoryName, 'Trail');
    });
    test('pure sequence (run + flush)', () {
      expect(eval('AS KS QS').categoryName, 'Pure Sequence');
    });
    test('sequence (run, mixed suits)', () {
      expect(eval('AS KH QS').categoryName, 'Sequence');
    });
    test('color (flush, not a run)', () {
      expect(eval('AS TS 7S').categoryName, 'Color');
    });
    test('pair', () {
      expect(eval('AS AH 9D').categoryName, 'Pair');
    });
    test('high card', () {
      expect(eval('AS TH 7D').categoryName, 'High Card');
    });
    test('A-2-3 is a sequence', () {
      expect(eval('AS 2H 3D').categoryName, 'Sequence');
    });
    test('A-2-3 same suit is a pure sequence', () {
      expect(eval('AS 2S 3S').categoryName, 'Pure Sequence');
    });
    test('Q-K-2 is not a sequence (just high card)', () {
      expect(eval('QS KH 2D').categoryName, 'High Card');
    });
  });

  group('Category ordering', () {
    test('trail beats pure sequence beats sequence beats color beats pair beats high card',
        () {
      final trail = eval('2S 2H 2D');
      final pure = eval('AS KS QS');
      final seq = eval('AS KH QS');
      final color = eval('AS TS 7S');
      final pair = eval('AS AH 9D');
      final high = eval('AS TH 7D');
      expect(trail.beats(pure), isTrue);
      expect(pure.beats(seq), isTrue);
      expect(seq.beats(color), isTrue);
      expect(color.beats(pair), isTrue);
      expect(pair.beats(high), isTrue);
    });
  });

  group('Run ordering (A-K-Q > A-2-3 > K-Q-J > ... > 4-3-2)', () {
    test('A-K-Q is the strongest run', () {
      expect(eval('AS KH QD').beats(eval('AS 2H 3D')), isTrue);
    });
    test('A-2-3 beats K-Q-J', () {
      expect(eval('AS 2H 3D').beats(eval('KS QH JD')), isTrue);
    });
    test('K-Q-J beats Q-J-10', () {
      expect(eval('KS QH JD').beats(eval('QS JH TD')), isTrue);
    });
    test('4-3-2 is the weakest run', () {
      expect(eval('5S 4H 3D').beats(eval('4S 3H 2D')), isTrue);
    });
  });

  group('Within-category tie-breakers', () {
    test('higher trail wins', () {
      expect(eval('AS AH AD').beats(eval('KS KH KD')), isTrue);
    });
    test('higher pair wins; kicker breaks equal pairs', () {
      expect(eval('KS KH 2D').beats(eval('QS QH AD')), isTrue);
      expect(eval('KS KH AD').beats(eval('KS KC 9D')), isTrue);
    });
    test('color compares top cards downward', () {
      expect(eval('AS QS 9S').beats(eval('AS JS TS')), isTrue);
    });
    test('high card compares top cards downward', () {
      expect(eval('AS QH 9D').beats(eval('AS JH TD')), isTrue);
    });
  });

  test('rejects hands that are not exactly 3 cards', () {
    expect(() => game.evaluate(hand('AS KS')), throwsArgumentError);
    expect(() => game.evaluate(hand('AS KS QS JS')), throwsArgumentError);
  });

  group('Double-deck ties (identical face values)', () {
    test('two identical hands tie exactly', () {
      final a = [card('AS'), card('AH'), card('AD')];
      final b = [card('AS', deckIndex: 1), card('AH', deckIndex: 1), card('AD', deckIndex: 1)];
      expect(game.evaluate(a).tiesWith(game.evaluate(b)), isTrue);
    });

    test('determineWinners returns all tied players (split pot)', () {
      final entries = [
        ShowdownEntry('p1', [card('AS'), card('AH'), card('AD')]),
        ShowdownEntry('p2', [card('AS', deckIndex: 1), card('AH', deckIndex: 1), card('AD', deckIndex: 1)]),
        ShowdownEntry('p3', [card('KS'), card('KH'), card('KD')]),
      ];
      final winners = game.determineWinners(entries);
      expect(winners, containsAll(['p1', 'p2']));
      expect(winners, isNot(contains('p3')));
      expect(winners.length, 2);
    });

    test('single clear winner', () {
      final entries = [
        ShowdownEntry('p1', hand('AS KS QS')), // pure sequence
        ShowdownEntry('p2', hand('AH AD 9C')), // pair
      ];
      expect(game.determineWinners(entries), ['p1']);
    });
  });
}
