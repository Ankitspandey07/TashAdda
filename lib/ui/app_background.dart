import 'package:flutter/material.dart';

/// Full-screen gradient used behind every screen so no scaffold edge shows.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF16264F), Color(0xFF0B142E)],
  );

  static const fillColor = Color(0xFF0B142E);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: fillColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          child,
        ],
      ),
    );
  }
}

/// Responsive content width for buttons and cards.
double responsiveContentWidth(BuildContext context, {double pad = 24}) {
  final w = MediaQuery.sizeOf(context).width;
  return w - pad * 2;
}

/// Square app logo size — ~13% of screen width, like the reference layout.
double responsiveLogoSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.32).clamp(120.0, 150.0);
}

double responsiveTitleSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.095).clamp(30.0, 40.0);
}

/// Centered logo + title block for the home screen.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final logoSize = responsiveLogoSize(context);
    final radius = logoSize * 0.2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.asset(
                  'assets/logo.png',
                  width: logoSize,
                  height: logoSize,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: logoSize * 0.12),
        Text(
          'TashAdda',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: responsiveTitleSize(context),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Card Games · Play with Friends',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: responsiveTitleSize(context) * 0.38,
          ),
        ),
      ],
    );
  }
}
