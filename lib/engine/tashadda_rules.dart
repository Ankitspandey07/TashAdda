/// TashAdda Teen Patti rules — shown in-app for players.
const List<String> kTashaddaRules = [
  'Starting chips: 1000 (online/LAN default). Boot is posted each round.',
  'Blind chaal: max 8 chaals per round. Seen players pay double until the 8th chaal.',
  'After the 8th chaal, every active player sees their cards automatically.',
  'After auto-show, everyone pays the same chaal amount (no seen double).',
  'Max 25 chaals per round (8 blind phase + up to 17 after cards are shown).',
  'At chaal 25 the round ends in a showdown if 2+ players remain.',
  'Blind: call = stake · raise = 2× stake. Seen (before equal phase): call = 2× · raise = 4×.',
  'When your chips cannot cover the next chaal, you may Show (if 2 players left) or Pack.',
  'If you skip Show and chaal again without enough chips, you are auto-packed.',
  'Zero chips = packed. Last player standing wins the pot.',
  'Sideshow: pick a seen opponent · they Accept/Reject (5s) · weaker hand packs.',
  'Show (2 players): pay chaal and compare all hands · winner takes the pot.',
  'Exit online/LAN: your seat shows “Exited” · others keep playing.',
  'Exit vs bots: leaves the table and closes the game for you.',
];
