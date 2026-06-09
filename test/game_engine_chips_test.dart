import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti_app/engine/game_engine.dart';

void main() {
  test('boot cannot exceed startChips', () {
    expect(
      () => GameEngine(boot: 100, startChips: 50),
      throwsArgumentError,
    );
  });

  test('default table uses 1000 chip limit', () {
    final engine = GameEngine(boot: 10);
    expect(engine.startChips, 1000);
    expect(engine.boot, 10);
  });
}
