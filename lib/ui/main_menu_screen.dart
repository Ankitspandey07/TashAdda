import 'package:flutter/material.dart';

import '../ads/banner_ad_widget.dart';
import 'app_background.dart';
import 'create_room_screen.dart';
import 'local_play_screen.dart';
import 'online_screen.dart';
import 'profile_widget.dart';
import 'search_rooms_screen.dart';
import 'support_widget.dart';
import 'tashadda_rules_sheet.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBackground.fillColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      floatingActionButton: const SupportFab(heroTag: 'support-menu'),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppBackground(
              child: SafeArea(
                left: false,
                right: false,
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 72),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: HomeHeader()),
                            SizedBox(height: responsiveLogoSize(context) * 0.14),
                            const Center(child: ProfileHeader()),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => showTashaddaRules(context),
                              icon: const Icon(Icons.menu_book_outlined,
                                  size: 18),
                              label: const Text('TashAdda rules'),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            _MenuButton(
                              icon: Icons.smart_toy,
                              label: 'Play vs Bots',
                              color: const Color(0xFF2E7D32),
                              onTap: () =>
                                  _go(context, const LocalPlayScreen()),
                            ),
                            const SizedBox(height: 14),
                            const _SectionLabel('Online · Internet'),
                            _MenuButton(
                              icon: Icons.public,
                              label: 'Play Online (Room Code)',
                              color: const Color(0xFF6A1B9A),
                              onTap: () => _go(context, const OnlineScreen()),
                            ),
                            const SizedBox(height: 14),
                            const _SectionLabel('Offline · Same Wi-Fi / Hotspot'),
                            _MenuButton(
                              icon: Icons.wifi_tethering,
                              label: 'Create Local Room (Host)',
                              color: const Color(0xFF1565C0),
                              onTap: () =>
                                  _go(context, const CreateRoomScreen()),
                            ),
                            const SizedBox(height: 10),
                            _MenuButton(
                              icon: Icons.travel_explore,
                              label: 'Search Local Rooms (Join)',
                              color: const Color(0xFF0277BD),
                              onTap: () =>
                                  _go(context, const SearchRoomsScreen()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: BannerAdWidget(),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, textAlign: TextAlign.left),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
