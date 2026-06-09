import 'package:flutter/material.dart';

const _suitSymbol = {'S': '\u2660', 'H': '\u2665', 'D': '\u2666', 'C': '\u2663'};
const _rankLabel = {'T': '10', 'J': 'J', 'Q': 'Q', 'K': 'K', 'A': 'A'};

String _rankText(String r) => _rankLabel[r] ?? r;

/// A single playing card. [code] is a 2-char code like `AS`; when null, the card
/// is rendered face-down.
class CardWidget extends StatelessWidget {
  const CardWidget({super.key, this.code, this.width = 40});

  final String? code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;
    final radius = width * 0.16;

    if (code == null) {
      return Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF24306B), Color(0xFF131C44)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFC9A24B), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Icon(Icons.diamond_outlined,
              color: const Color(0xFFC9A24B), size: width * 0.5),
        ),
      );
    }

    final rank = _rankText(code![0]);
    final suit = _suitSymbol[code![1]] ?? '?';
    final red = code![1] == 'H' || code![1] == 'D';
    final color = red ? const Color(0xFFD32F2F) : const Color(0xFF15171C);

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF1F1F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 3,
            child: Text(rank,
                style: TextStyle(
                    color: color,
                    fontSize: width * 0.34,
                    fontWeight: FontWeight.bold,
                    height: 1)),
          ),
          Center(
            child: Text(suit,
                style: TextStyle(color: color, fontSize: width * 0.6)),
          ),
          Positioned(
            bottom: 2,
            right: 3,
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(rank,
                  style: TextStyle(
                      color: color,
                      fontSize: width * 0.34,
                      fontWeight: FontWeight.bold,
                      height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
