import '../../models/card.dart';
import '../../models/deck.dart';
import '../hand_result.dart';
import '../i_card_game.dart';
import 'teen_patti_game.dart';

/// Muflis ("lowball") Teen Patti: the *weakest* normal hand wins. It reuses the
/// standard [TeenPattiGame] evaluation and simply inverts the result so the same
/// max-based [determineWinners] picks the lowest hand. This is a deliberate
/// showcase of the modular [ICardGame] interface — a whole new game with zero
/// new evaluation logic.
class MuflisGame implements ICardGame {
  const MuflisGame();

  final TeenPattiGame _base = const TeenPattiGame();

  @override
  String get id => 'muflis';

  @override
  String get name => 'Muflis (Lowball)';

  @override
  int get minPlayers => _base.minPlayers;

  @override
  int get maxPlayers => _base.maxPlayers;

  @override
  int get cardsPerPlayer => _base.cardsPerPlayer;

  @override
  Deck buildDeck(int playerCount) => _base.buildDeck(playerCount);

  @override
  HandResult evaluate(List<PlayingCard> cards) {
    final r = _base.evaluate(cards);
    // Invert: a strong Teen Patti hand becomes a weak Muflis hand. Categories
    // are 1..6, so 7 - category flips the order; negating tie-breakers flips
    // within a category (lower kicker now ranks higher).
    return HandResult(
      category: 7 - r.category,
      categoryName: '${r.categoryName} (low)',
      tieBreakers: r.tieBreakers.map((v) => -v).toList(),
    );
  }

  @override
  int compare(List<PlayingCard> a, List<PlayingCard> b) =>
      evaluate(a).compareTo(evaluate(b));

  @override
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
