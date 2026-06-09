import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/rewarded_ads.dart';

const String kUpiId = 'tashadda@upi';
const String kUpiName = 'TashAdda';
const String kFeedbackEmail = 'ankitspandeyofficial@gmail.com';

/// `upi://` deep link used both for the "Pay via UPI app" button and the QR.
String upiUri({int? amount}) {
  final params = <String, String>{
    'pa': kUpiId,
    'pn': kUpiName,
    'cu': 'INR',
    'tn': 'Support TashAdda',
    if (amount != null) 'am': '$amount',
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'upi://pay?$query';
}

/// A small, gently pulsing round "chatbot" button to drop in a screen corner.
/// Tapping it opens the support + feedback panel.
class SupportFab extends StatefulWidget {
  const SupportFab({super.key, this.heroTag = 'support'});
  final String heroTag;

  @override
  State<SupportFab> createState() => _SupportFabState();
}

class _SupportFabState extends State<SupportFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.06).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: FloatingActionButton(
        heroTag: widget.heroTag,
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: Colors.black,
        onPressed: () => showSupportPanel(context),
        child: const Icon(Icons.favorite),
      ),
    );
  }
}

Future<void> showSupportPanel(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14213D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _SupportPanel(),
  );
}

class _SupportPanel extends StatefulWidget {
  const _SupportPanel();

  @override
  State<_SupportPanel> createState() => _SupportPanelState();
}

class _SupportPanelState extends State<_SupportPanel> {
  final _msgCtrl = TextEditingController();
  final _gameOptions = const [
    'Poker',
    'Rummy',
    'Andar Bahar',
    'Call Break',
    'Bluff (online)',
    'Solitaire',
    'UNO style',
    'Blackjack',
  ];
  final Set<String> _wanted = {};
  bool _sent = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _payUpi() async {
    final uri = Uri.parse(upiUri());
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('No UPI app found. UPI: $kUpiId (copied)');
      if (!ok) await Clipboard.setData(const ClipboardData(text: kUpiId));
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: kUpiId));
      _toast('No UPI app found. UPI: $kUpiId (copied)');
    }
  }

  Future<void> _watchAd() async {
    final ok = await RewardedAds.show();
    if (!mounted) return;
    _toast(ok ? 'Thanks for watching! ❤️' : 'Ad not ready — try again soon.');
  }

  Future<void> _sendFeedback() async {
    final body = StringBuffer()
      ..writeln('Games I want next: '
          '${_wanted.isEmpty ? '(none selected)' : _wanted.join(', ')}')
      ..writeln()
      ..writeln('Feedback / suggestions:')
      ..writeln(_msgCtrl.text.trim());
    final uri = Uri(
      scheme: 'mailto',
      path: kFeedbackEmail,
      queryParameters: {
        'subject': 'TashAdda feedback',
        'body': body.toString(),
      },
    );
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: body.toString()));
    }
    if (mounted) setState(() => _sent = true);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFB300),
                  child: Icon(Icons.emoji_emotions, color: Colors.black),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Enjoying TashAdda?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('“Khel waही जो dil जोड़े — share कर, sath में jeet!”',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28, color: Colors.white24),
            // Support / donate
            const Text('Support development',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: QrImageView(
                    data: upiUri(),
                    size: 110,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scan to pay, or use UPI:',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                              const ClipboardData(text: kUpiId));
                          _toast('UPI ID copied');
                        },
                        child: Row(
                          children: const [
                            Text(kUpiId,
                                style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            SizedBox(width: 6),
                            Icon(Icons.copy, size: 14, color: Colors.white54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _payUpi,
                        icon: const Icon(Icons.account_balance_wallet, size: 18),
                        label: const Text('Pay via UPI app'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _watchAd,
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('Watch ad to support'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFD54F)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28, color: Colors.white24),
            // Feedback
            const Text('Tell us what to build next',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Which games do you want?',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in _gameOptions)
                  FilterChip(
                    label: Text(g),
                    selected: _wanted.contains(g),
                    onSelected: (s) => setState(() =>
                        s ? _wanted.add(g) : _wanted.remove(g)),
                    selectedColor: const Color(0xFF6A1B9A),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                        color: _wanted.contains(g)
                            ? Colors.white
                            : Colors.white70),
                    backgroundColor: Colors.white10,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Your feedback or suggestions…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Thank you! Your feedback means a lot. ❤️',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _sendFeedback,
                icon: const Icon(Icons.send),
                label: const Text('Send feedback'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
