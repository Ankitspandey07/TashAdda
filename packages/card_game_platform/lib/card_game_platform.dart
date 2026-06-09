/// Framework-agnostic core for the multi-mode card game platform.
///
/// Phase 1 surface: data models, dynamic deck scaling, the modular [ICardGame]
/// interface, the round state machine, and the Teen Patti evaluator.
library card_game_platform;

export 'src/models/card.dart';
export 'src/models/deck.dart';
export 'src/models/player.dart';
export 'src/models/game_state.dart';
export 'src/games/hand_result.dart';
export 'src/games/i_card_game.dart';
export 'src/games/teen_patti/teen_patti_game.dart';
export 'src/games/teen_patti/muflis_game.dart';
