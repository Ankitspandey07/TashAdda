import '../../models/card.dart';
import '../../models/deck.dart';
import '../hand_result.dart';
import '../i_card_game.dart';

/// Teen Patti hand categories, weakest to strongest. The integer index is used
/// as [HandResult.category].
enum TeenPattiCategory {
  highCard(1, 'High Card'),
  pair(2, 'Pair'),
  color(3, 'Color'),
  sequence(4, 'Sequence'),
  pureSequence(5, 'Pure Sequence'),
  trail(6, 'Trail');

  const TeenPattiCategory(this.score, this.label);
  final int score;
  final String label;
}

/// Teen Patti, three-card poker-style game.
///
/// Ranking (high to low): Trail > Pure Sequence > Sequence > Color > Pair >
/// High Card.
///
/// Run ordering assumption (documented because variants differ): A-K-Q is the
/// highest run and A-2-3 is the second highest; after that runs rank by their
/// top card (K-Q-J down to 4-3-2). This is the common Indian Teen Patti rule.
/// To switch to the "A-2-3 is lowest" variant, change [_runValue].
///
/// Double deck: this evaluator only reads rank/suit, never [PlayingCard.deckIndex],
/// so two players holding the same face values produce equal [HandResult]s and
/// tie (split pot) — exactly what the >5-player double-deck rule requires.
class TeenPattiGame implements ICardGame {
  const TeenPattiGame();

  @override
  String get id => 'teen_patti';

  @override
  String get name => 'Teen Patti';

  @override
  int get minPlayers => 3;

  @override
  int get maxPlayers => 5;

  @override
  int get cardsPerPlayer => 3;

  @override
  Deck buildDeck(int playerCount) => Deck.forPlayers(playerCount);

  @override
  HandResult evaluate(List<PlayingCard> cards) {
    if (cards.length != 3) {
      throw ArgumentError.value(
          cards.length, 'cards', 'Teen Patti hands must have exactly 3 cards');
    }

    // Ranks sorted high -> low for kicker comparisons.
    final ranks = cards.map((c) => c.rank.value).toList()
      ..sort((a, b) => b.compareTo(a));
    final isFlush = cards.every((c) => c.suit == cards.first.suit);
    final runValue = _runValue(ranks);
    final isRun = runValue != null;

    // Trail: three of a kind.
    if (ranks[0] == ranks[1] && ranks[1] == ranks[2]) {
      return _result(TeenPattiCategory.trail, [ranks[0]]);
    }
    // Pure sequence: run + same suit.
    if (isRun && isFlush) {
      return _result(TeenPattiCategory.pureSequence, [runValue]);
    }
    // Sequence: run, mixed suits.
    if (isRun) {
      return _result(TeenPattiCategory.sequence, [runValue]);
    }
    // Color: flush, not a run.
    if (isFlush) {
      return _result(TeenPattiCategory.color, ranks);
    }
    // Pair: exactly two equal ranks.
    final pair = _pairTieBreakers(ranks);
    if (pair != null) {
      return _result(TeenPattiCategory.pair, pair);
    }
    // High card.
    return _result(TeenPattiCategory.highCard, ranks);
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

  HandResult _result(TeenPattiCategory category, List<int> tieBreakers) =>
      HandResult(
        category: category.score,
        categoryName: category.label,
        tieBreakers: tieBreakers,
      );

  /// Returns a comparable value for a run, or `null` if the three ranks are not
  /// a run. Higher value = stronger run.
  ///
  /// [ranksDesc] is sorted high -> low.
  static int? _runValue(List<int> ranksDesc) {
    final set = ranksDesc.toSet();
    if (set.length != 3) return null; // duplicates can't form a run

    // A-K-Q (14,13,12): highest run.
    if (set.containsAll({14, 13, 12})) return 15;
    // A-2-3 (14,3,2): low-ace run, second highest.
    if (set.containsAll({14, 3, 2})) return 14;
    // Otherwise must be three consecutive ranks; value = top card (4..13).
    if (ranksDesc[0] - ranksDesc[1] == 1 && ranksDesc[1] - ranksDesc[2] == 1) {
      return ranksDesc[0];
    }
    return null;
  }

  /// For a pair, returns `[pairRank, kicker]`; otherwise `null`.
  static List<int>? _pairTieBreakers(List<int> ranksDesc) {
    if (ranksDesc[0] == ranksDesc[1]) return [ranksDesc[0], ranksDesc[2]];
    if (ranksDesc[1] == ranksDesc[2]) return [ranksDesc[1], ranksDesc[0]];
    return null;
  }
}
