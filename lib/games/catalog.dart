import 'package:card_game_platform/card_game_platform.dart';
import 'package:flutter/material.dart';

/// An entry in the lobby's game catalog. Games plug in via the modular
/// [ICardGame] interface; entries without a [game] are placeholders for games
/// that are architected but not yet implemented.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.description,
    required this.icon,
    this.game,
    this.isBluff = false,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Set for hand-ranking games (Teen Patti family) that run on the shared
  /// betting engine + felt table.
  final ICardGame? game;

  /// Set for the Bluff game, which has its own engine and table UI.
  final bool isBluff;

  bool get playable => game != null || isBluff;

  /// True for games that use the betting engine + [TableScreen] (and therefore
  /// also work in LAN/online modes).
  bool get isHandRanking => game != null;
}

/// The catalog shown in the lobby. Teen Patti and Muflis are fully playable and
/// reuse the same table; others are placeholders kept honest as "coming soon".
const List<GameEntry> kGameCatalog = [
  GameEntry(
    title: 'Classic',
    description: 'Classic 3-card game · Trail beats everything',
    icon: Icons.style,
    game: TeenPattiGame(),
  ),
  GameEntry(
    title: 'Muflis',
    description: 'Lowball · the weakest hand wins',
    icon: Icons.swap_vert,
    game: MuflisGame(),
  ),
  GameEntry(
    title: 'Bluff (Cheat)',
    description: 'Discard & bluff · call out the liar',
    icon: Icons.theater_comedy,
    isBluff: true,
  ),
  GameEntry(
    title: 'Poker',
    description: '5-card Texas Hold\'em style',
    icon: Icons.casino,
  ),
  GameEntry(
    title: 'Rummy',
    description: 'Form sequences & sets',
    icon: Icons.view_module,
  ),
];

/// Games that run on the shared betting engine + table.
final List<GameEntry> kHandRankingGames =
    kGameCatalog.where((g) => g.isHandRanking).toList();

/// Games playable in online multiplayer: the hand-ranking family plus Bluff.
final List<GameEntry> kOnlineGames =
    kGameCatalog.where((g) => g.isHandRanking || g.isBluff).toList();
