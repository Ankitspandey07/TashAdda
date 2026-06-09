import 'package:flutter/material.dart';

/// Boot ante and per-round chip limit for Teen Patti tables.
class TableRules {
  const TableRules({this.boot = 10, this.startChips = 1000});

  final int boot;
  final int startChips;

  String get summary => 'Boot $boot · $startChips chips per round';
}

/// Host configures boot + starting chips before creating a room or dealing.
class TableRulesSteppers extends StatelessWidget {
  const TableRulesSteppers({
    super.key,
    required this.boot,
    required this.startChips,
    required this.onBootChanged,
    required this.onStartChipsChanged,
    this.enabled = true,
  });

  final int boot;
  final int startChips;
  final ValueChanged<int> onBootChanged;
  final ValueChanged<int> onStartChipsChanged;
  final bool enabled;

  static const int minChips = 200;
  static const int maxChips = 5000;
  static const int chipsStep = 100;
  static const int minBoot = 2;
  static const int maxBoot = 100;
  static const int bootStep = 2;

  int get _maxBoot => startChips.clamp(minBoot, maxBoot);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepper(
          context,
          label: 'Starting chips (per round)',
          value: startChips,
          min: minChips,
          max: maxChips,
          step: chipsStep,
          onChanged: (v) {
            onStartChipsChanged(v);
            if (boot > v) onBootChanged(v.clamp(minBoot, maxBoot));
          },
        ),
        _stepper(
          context,
          label: 'Boot (ante)',
          value: boot.clamp(minBoot, _maxBoot),
          min: minBoot,
          max: _maxBoot,
          step: bootStep,
          onChanged: onBootChanged,
        ),
        Text(
          TableRules(boot: boot, startChips: startChips).summary,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const Text(
          'Everyone starts each round with the chip limit. Broke players must Show or Pack.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _stepper(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: !enabled || value <= min
                ? null
                : () => onChanged(value - step),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: !enabled || value >= max
                ? null
                : () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

/// Read-only rules line shown in lobbies.
class TableRulesBanner extends StatelessWidget {
  const TableRulesBanner({
    super.key,
    required this.boot,
    required this.startChips,
  });

  final int boot;
  final int startChips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        TableRules(boot: boot, startChips: startChips).summary,
        style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
