import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../engine/game_engine.dart';
import '../net/table_chat.dart';
import '../profile/profile_store.dart';
import '../score/scoreboard.dart';
import '../table/table_view.dart';
import 'card_widget.dart';
import 'emoji_chat.dart';
import 'exit_confirm.dart';
import 'profile_widget.dart';
import 'session_summary_screen.dart';
import 'tashadda_rules_sheet.dart';

/// Renders any [TableController] (local engine or network client) as a felt
/// table with players seated around the rim.
class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.controller,
    this.onLeave,
    this.chat,
    this.closeGameOnExit = false,
  });

  final TableController controller;
  final VoidCallback? onLeave;

  /// Optional networked chat/avatar channel; null for single-device play.
  final TableChat? chat;

  /// When true (vs bots), exit closes the game. When false, others keep playing.
  final bool closeGameOnExit;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  bool _celebrated = false;

  int _shownSideshowSeq = 0;
  SideshowReveal? _activeSideshow;
  Timer? _sideshowTimer;

  @override
  void initState() {
    super.initState();
    // Share my avatar with the table once connected.
    if (widget.chat != null) {
      Future.delayed(const Duration(milliseconds: 600),
          () => widget.chat?.shareAvatar());
    }
    widget.controller.onSessionEnd = _onHostClosedRoom;
  }

  void _onHostClosedRoom(SessionSummary summary) {
    if (!mounted) return;
    _showSessionSummary(summary, celebrate: true).then((_) {
      if (mounted) widget.onLeave?.call();
    });
  }

  Future<void> _showSessionSummary(SessionSummary summary,
      {required bool celebrate}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SessionSummaryScreen(
          summary: summary,
          celebrate: celebrate,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confetti.dispose();
    _sideshowTimer?.cancel();
    super.dispose();
  }

  void _onFrame(TableView v) {
    // Winner celebration (works for local host and remote clients).
    final youWon = v.phase == RoundPhase.roundOver &&
        v.seats.any((s) => s.isYou && s.status.contains('Winner'));
    if (v.phase == RoundPhase.roundOver && !_celebrated) {
      _celebrated = true;
      Sfx.instance.win();
      if (youWon) _confetti.play();
    } else if (v.phase != RoundPhase.roundOver) {
      _celebrated = false;
    }

    // New sideshow to reveal?
    final ss = v.sideshow;
    if (ss != null && ss.seq > _shownSideshowSeq) {
      _shownSideshowSeq = ss.seq;
      _activeSideshow = ss;
      _sideshowTimer?.cancel();
      _sideshowTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _activeSideshow = null);
      });
      // setState happens via the outer AnimatedBuilder rebuild already in
      // progress; schedule a microtask to ensure the overlay shows.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _leave() async {
    if (widget.onLeave == null) return;
    if (!await confirmExit(
      context,
      message: widget.closeGameOnExit
          ? 'Are you sure you want to exit? The game will close.'
          : null,
    )) {
      return;
    }
    final summary = widget.controller.sessionSummary;
    if (!widget.closeGameOnExit) {
      widget.controller.leaveTable();
    }
    if (summary != null && summary.roundsPlayed > 0 && mounted) {
      await _showSessionSummary(summary, celebrate: false);
    }
    if (mounted) widget.onLeave!();
  }

  Future<void> _closeRoom() async {
    if (!widget.controller.canCloseRoom) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close room?'),
        content: const Text(
          'This ends the game for everyone. Session results will be shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close room'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final summary = widget.controller.sessionSummary;
    widget.controller.closeRoom();
    if (summary != null && summary.roundsPlayed > 0) {
      await _showSessionSummary(summary, celebrate: true);
    }
    if (mounted) widget.onLeave?.call();
  }

  Future<void> _pickSideshow(TableView v, TableController c) async {
    if (v.sideshowTargets.isEmpty) return;
    if (v.sideshowTargets.length == 1) {
      c.requestSideshow(v.sideshowTargets.first.id);
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF14213D),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Choose player for sideshow',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            for (final t in v.sideshowTargets)
              ListTile(
                leading: const Icon(Icons.person, color: Colors.amber),
                title:
                    Text(t.name, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) c.requestSideshow(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final v = widget.controller.view;
        WidgetsBinding.instance.addPostFrameCallback((_) => _onFrame(v));
        return Scaffold(
          backgroundColor: const Color(0xFF0B142E),
          appBar: AppBar(
            title: Text(widget.controller.title),
            backgroundColor: const Color(0xFF0B142E),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'TashAdda rules',
                onPressed: () => showTashaddaRules(context),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Sfx.muted,
                builder: (context, muted, _) => IconButton(
                  icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                  tooltip: muted ? 'Unmute' : 'Mute',
                  onPressed: () => Sfx.muted.value = !muted,
                ),
              ),
              if (widget.controller.canCloseRoom)
                IconButton(
                  icon: const Icon(Icons.meeting_room_outlined),
                  tooltip: 'Close room',
                  onPressed: _closeRoom,
                ),
              if (widget.onLeave != null)
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _leave,
                  tooltip: 'Leave',
                ),
            ],
          ),
          body: ChatOverlay(
            chat: widget.chat,
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                          child: _Felt(view: v, onSeeCards: widget.controller.see)),
                      if (v.standings.isNotEmpty) _ScoreStrip(view: v),
                      _LogStrip(log: v.log),
                      _ActionBar(
                        controller: widget.controller,
                        view: v,
                        onSideshow: () => _pickSideshow(v, widget.controller),
                      ),
                    ],
                  ),
                  // Winner banner.
                  if (v.phase == RoundPhase.roundOver &&
                      v.winnerBanner.isNotEmpty)
                    _WinnerBanner(text: v.winnerBanner),
                  // Sideshow reveal.
                  if (_activeSideshow != null)
                    _SideshowOverlay(
                      reveal: _activeSideshow!,
                      onClose: () {
                        _sideshowTimer?.cancel();
                        setState(() => _activeSideshow = null);
                      },
                    ),
                  if (v.pendingSideshow != null)
                    _PendingSideshowOverlay(
                      pending: v.pendingSideshow!,
                      onRespond: widget.controller.respondSideshow,
                    ),
                  const _BrandLogo(),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      numberOfParticles: 24,
                      gravity: 0.25,
                      colors: const [
                        Color(0xFFFFD54F),
                        Color(0xFF2E7D32),
                        Color(0xFF1565C0),
                        Color(0xFFC62828),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The green felt with the pot in the middle and seats around the edge.
class _Felt extends StatelessWidget {
  const _Felt({required this.view, required this.onSeeCards});
  final TableView view;
  final VoidCallback onSeeCards;

  @override
  Widget build(BuildContext context) {
    // Order seats so the local viewer is "slot 0" (bottom center).
    final seats = [...view.seats];
    final youIdx = seats.indexWhere((s) => s.isYou);
    final ordered = youIdx <= 0
        ? seats
        : [...seats.sublist(youIdx), ...seats.sublist(0, youIdx)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = w / 2;
        final cy = h / 2;
        final n = ordered.length;

        // Scale seat size to the screen so nothing clips on small phones.
        final sw = (w * 0.22).clamp(74.0, 104.0);
        final sh = sw * 1.34;

        // Keep the whole seat box inside the felt by insetting the radii by
        // half the seat size (plus a small margin).
        final rx = math.max(0.0, (w / 2) - (sw / 2) - 8);
        final ry = math.max(0.0, (h / 2) - (sh / 2) - 8);

        // You sit at the bottom; opponents fan across the top, leaving the
        // top-centre clear for the dealer so nobody overlaps her.
        final angles = _seatAngles(n);
        final seatWidgets = <Widget>[];
        for (var i = 0; i < n; i++) {
          final theta = angles[i];
          final x = cx + rx * math.cos(theta);
          final y = cy + ry * math.sin(theta);
          seatWidgets.add(Positioned(
            left: x - sw / 2,
            top: y - sh / 2,
            width: sw,
            height: sh,
            child: _SeatWidget(
              seat: ordered[i],
              width: sw,
              onSeeCards: onSeeCards,
            ),
          ));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: w * 0.9,
                height: h * 0.82,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h * 0.41),
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF1E8A4C),
                      Color(0xFF0B5E2E),
                      Color(0xFF073D1E)
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                  border: Border.all(color: const Color(0xFFC9A24B), width: 5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54, blurRadius: 24, spreadRadius: 4),
                  ],
                ),
              ),
            ),
            // Dealer at top-center (seats are arranged to leave room here).
            Positioned(
              top: 0,
              left: cx - (sw * 0.5),
              width: sw,
              child: _Dealer(width: sw),
            ),
            Center(child: _PotChips(view: view)),
            ...seatWidgets,
          ],
        );
      },
    );
  }

  /// Angles (radians, y-down) for [n] seats: index 0 at the bottom (the local
  /// player), the rest fanned across the top while keeping a gap at the very
  /// top-centre for the dealer.
  static List<double> _seatAngles(int n) {
    const bottom = math.pi / 2;
    const top = 3 * math.pi / 2;
    final angles = <double>[bottom];
    final others = n - 1;
    if (others <= 0) return angles;

    const minDelta = 0.55; // half-gap reserved for the dealer
    const maxDelta = 1.45; // how far down the sides opponents may go
    final leftN = others ~/ 2;
    final rightN = others - leftN;

    double delta(int k, int count) {
      if (count == 1) return minDelta + 0.35;
      return minDelta + (maxDelta - minDelta) * (k / (count - 1));
    }

    for (var k = 0; k < leftN; k++) {
      angles.add(top - delta(k, leftN)); // left of the dealer
    }
    for (var k = 0; k < rightN; k++) {
      angles.add(top + delta(k, rightN)); // right of the dealer
    }
    return angles;
  }
}

class _Dealer extends StatelessWidget {
  const _Dealer({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/img/dealer.png',
            width: width, fit: BoxFit.contain),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Dealer',
              style: TextStyle(color: Colors.white70, fontSize: 10)),
        ),
      ],
    );
  }
}

class _PotChips extends StatelessWidget {
  const _PotChips({required this.view});
  final TableView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.savings, color: Color(0xFFFFD54F), size: 28),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC9A24B), width: 1),
          ),
          child: Text('POT  ${view.pot}',
              style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ),
        const SizedBox(height: 4),
        Text('Stake ${view.stake}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('Chaal ${view.chaalCount}/${view.maxChaals}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

/// Red-framed TashAdda logo — top-left below the app bar.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      left: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC62828), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66C62828), blurRadius: 8),
            ],
          ),
          child: Image.asset('assets/logo.png', width: 34, height: 34),
        ),
      ),
    );
  }
}

class _SeatWidget extends StatelessWidget {
  const _SeatWidget(
      {required this.seat, required this.width, required this.onSeeCards});
  final SeatView seat;
  final double width;
  final VoidCallback onSeeCards;

  @override
  Widget build(BuildContext context) {
    if (seat.exited) {
      return Opacity(
        opacity: 0.55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width * 0.55,
              height: width * 0.55,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_seat, color: Colors.white38, size: 28),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                seat.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Text('Exited',
                style: TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      );
    }

    final glow = seat.isTurn
        ? [
            const BoxShadow(
                color: Color(0xFFFFD54F), blurRadius: 16, spreadRadius: 2)
          ]
        : const <BoxShadow>[];
    final dim = seat.folded;
    final cardW = (width * 0.26).clamp(22.0, 32.0);

    // Your own face-down cards: tap to peek (blind play).
    final canPeek = seat.isYou && !seat.seen && !seat.folded;

    Widget cards = SizedBox(
      height: cardW * 1.7,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var c = 0; c < 3; c++)
            Transform.rotate(
              angle: (c - 1) * 0.12,
              child: CardWidget(
                code: (seat.hand != null && c < seat.hand!.length)
                    ? seat.hand![c]
                    : null,
                width: cardW,
              ),
            ),
        ],
      ),
    );
    if (canPeek) {
      cards = GestureDetector(onTap: onSeeCards, child: cards);
    }

    return Opacity(
      opacity: dim ? 0.45 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cards,
          if (canPeek)
            const Text('tap to see',
                style: TextStyle(color: Color(0xFFFFD54F), fontSize: 8)),
          const SizedBox(height: 2),
          Container(
            decoration:
                BoxDecoration(shape: BoxShape.circle, boxShadow: glow),
            child: seat.isYou
                ? const ProfileAvatar(radius: 20)
                : _OpponentAvatar(name: seat.name, folded: seat.folded),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        seat.isYou ? '${seat.name} (You)' : seat.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!seat.folded) ...[
                      const SizedBox(width: 3),
                      Icon(
                          seat.seen
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 11,
                          color: Colors.white54),
                    ],
                  ],
                ),
                Text('${seat.chips}',
                    style: const TextStyle(
                        color: Color(0xFFFFD54F), fontSize: 11)),
                if (seat.status.isNotEmpty)
                  Text(seat.status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.amberAccent, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opponent avatar: shows their shared photo if we've received one (keyed by
/// name), otherwise a default icon.
class _OpponentAvatar extends StatelessWidget {
  const _OpponentAvatar({required this.name, required this.folded});
  final String name;
  final bool folded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Uint8List>>(
      valueListenable: RemoteAvatars.byName,
      builder: (context, map, _) {
        final bytes = map[name];
        return CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF2E3A59),
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child: bytes != null
              ? null
              : Icon(
                  folded ? Icons.do_not_disturb : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
        );
      },
    );
  }
}

/// Center headline announcing the winner with name + amount + hand.
class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (context, s, child) =>
              Transform.scale(scale: s, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 16, spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 34),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay revealing a sideshow: who challenged whom and both hands.
class _SideshowOverlay extends StatelessWidget {
  const _SideshowOverlay({required this.reveal, required this.onClose});
  final SideshowReveal reveal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF14213D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC9A24B), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('SIDESHOW',
                    style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3)),
                const SizedBox(height: 14),
                _hand(reveal.requester, reveal.requesterHand,
                    reveal.winner == reveal.requester),
                const SizedBox(height: 8),
                const Text('vs', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 8),
                _hand(reveal.target, reveal.targetHand,
                    reveal.winner == reveal.target),
                const SizedBox(height: 14),
                Text('${reveal.winner} wins the sideshow 🏆',
                    style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('(tap to close)',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hand(String name, List<String> cards, bool won) {
    return Column(
      children: [
        Text(name,
            style: TextStyle(
                color: won ? const Color(0xFFFFD54F) : Colors.white,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: CardWidget(code: c, width: 38),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingSideshowOverlay extends StatelessWidget {
  const _PendingSideshowOverlay(
      {required this.pending, required this.onRespond});
  final PendingSideshowView pending;
  final void Function(bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    if (!pending.youAreTarget) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Card(
          color: const Color(0xFF14213D),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${pending.requesterName} wants a sideshow!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Accept to compare hands · auto-rejects in 5s',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => onRespond(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32)),
                      child: const Text('Accept'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => onRespond(false),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828)),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.view});
  final TableView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFF1A2A52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              for (final s in view.standings)
                Text(
                  '${s.name}: ${s.net >= 0 ? '+' : ''}${s.net}',
                  style: TextStyle(
                    color: s.net >= 0
                        ? const Color(0xFF81C784)
                        : const Color(0xFFE57373),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (view.scoreLog.isNotEmpty)
            Text(
              view.scoreLog.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _LogStrip extends StatelessWidget {
  const _LogStrip({required this.log});
  final List<String> log;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      width: double.infinity,
      alignment: Alignment.center,
      color: Colors.black.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        log.isEmpty ? '' : log.first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.view,
    required this.onSideshow,
  });
  final TableController controller;
  final TableView view;
  final VoidCallback onSideshow;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final c = controller;
    List<Widget> children;

    if (v.phase == RoundPhase.roundOver) {
      children = [
        ElevatedButton.icon(
          onPressed: c.nextRound,
          icon: const Icon(Icons.refresh),
          label: const Text('Next round'),
          style:
              ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
        ),
      ];
    } else if (v.phase == RoundPhase.sideshowPending && v.pendingSideshow != null) {
      final p = v.pendingSideshow!;
      if (p.youAreTarget) {
        children = [
          Text('${p.requesterName} wants a sideshow',
              style: const TextStyle(color: Colors.white70)),
          _btn('Accept', const Color(0xFF2E7D32),
              () => c.respondSideshow(true), icon: Icons.check),
          _btn('Reject', const Color(0xFFC62828),
              () => c.respondSideshow(false), icon: Icons.close),
        ];
      } else if (p.youAreRequester) {
        children = [
          Text('Waiting for ${p.targetName}…',
              style: const TextStyle(color: Colors.white70)),
        ];
      } else {
        children = [
          Text('Sideshow: ${p.requesterName} vs ${p.targetName}',
              style: const TextStyle(color: Colors.white70)),
        ];
      }
    } else if (v.yourTurn && v.mustShowOrPack) {
      children = [
        Text(
          'Not enough chips for the next chaal',
          style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        if (v.canShow)
          _btn('Show (all-in)', const Color(0xFF6A1B9A), c.show,
              icon: Icons.remove_red_eye),
        _btn('Pack', const Color(0xFFC62828), c.fold, icon: Icons.close),
        if (v.canShow)
          const Text('Skip Show and chaal → auto pack',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
      ];
    } else if (!v.yourTurn) {
      children = [
        if (!v.youSeen)
          _btn('See cards', const Color(0xFF455A87), c.see,
              icon: Icons.visibility),
        const Text('Waiting for other players…',
            style: TextStyle(color: Colors.white70)),
      ];
    } else {
      children = [
        if (!v.youSeen)
          _btn('See cards', const Color(0xFF455A87), c.see,
              icon: Icons.visibility),
        _btn(v.twoLeft ? 'Call ${v.callCost}' : 'Bet ${v.callCost}',
            const Color(0xFF1565C0), c.call, icon: Icons.check),
        if (v.canRaise && !v.mustShowOrPack)
          _btn('Raise ${v.raiseCost}', const Color(0xFF2E7D32), c.raise,
              icon: Icons.arrow_upward),
        if (v.canShow && !v.mustShowOrPack)
          _btn('Show ${v.callCost}', const Color(0xFF6A1B9A), c.show,
              icon: Icons.remove_red_eye),
        if (v.canSideshow)
          _btn('Sideshow', const Color(0xFF00897B), onSideshow,
              icon: Icons.compare_arrows),
        _btn('Pack', const Color(0xFFC62828), c.fold, icon: Icons.close),
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: const Color(0xFF0B142E),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap, {IconData? icon}) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon ?? Icons.circle, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
}
