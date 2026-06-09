import 'package:card_game_platform/card_game_platform.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  const muflis = MuflisGame();

  test('lowest hand wins in Muflis', () {
    // High card beats a trail in lowball.
    final entries = [
      ShowdownEntry('trail', hand('AS AH AD')),
      ShowdownEntry('low', hand('2S 5H 9D')),
    ];
    expect(muflis.determineWinners(entries), ['low']);
  });

  test('between two high-card hands, the lower one wins', () {
    expect(
      muflis.evaluate(hand('2S 5H 8D')).beats(muflis.evaluate(hand('AS QH 9D'))),
      isTrue,
    );
  });

  test('identical hands still tie (split pot)', () {
    final a = [card('2S'), card('5H'), card('9D')];
    final b = [card('2S', deckIndex: 1), card('5H', deckIndex: 1), card('9D', deckIndex: 1)];
    expect(muflis.evaluate(a).tiesWith(muflis.evaluate(b)), isTrue);
  });
}
