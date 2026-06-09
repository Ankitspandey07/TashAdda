import 'package:card_game_platform/card_game_platform.dart';

const _rankBySymbol = {
  '2': Rank.two,
  '3': Rank.three,
  '4': Rank.four,
  '5': Rank.five,
  '6': Rank.six,
  '7': Rank.seven,
  '8': Rank.eight,
  '9': Rank.nine,
  'T': Rank.ten,
  'J': Rank.jack,
  'Q': Rank.queen,
  'K': Rank.king,
  'A': Rank.ace,
};

const _suitBySymbol = {
  'S': Suit.spades,
  'H': Suit.hearts,
  'D': Suit.diamonds,
  'C': Suit.clubs,
};

/// Parses a compact code like `AS`, `TD`, `2C` into a [PlayingCard].
PlayingCard card(String code, {int deckIndex = 0}) {
  final rank = _rankBySymbol[code[0]]!;
  final suit = _suitBySymbol[code[1]]!;
  return PlayingCard(rank, suit, deckIndex: deckIndex);
}

/// Parses a space-separated hand like `AS KD QH`.
List<PlayingCard> hand(String codes) =>
    codes.split(RegExp(r'\s+')).map((c) => card(c)).toList();
