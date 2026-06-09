import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../net/table_chat.dart';

/// Quick reactions: emojis + trending Hindi meme one-liners to keep the table
/// lively.
const List<String> kQuickEmojis = [
  '😂', '🔥', '😎', '👏', '😱', '🤑', '💪', '🙏', '😭', '🤣', '🤨', '🥳',
];

const List<String> kHindiStickers = [
  'Bhai sab fold 😏',
  'Paisa hi paisa hoga 🤑',
  'Rula diya 😭',
  'Sahi pakde hain! 🫵',
  'Tension nahi lene ka 😎',
  'Blind hi khelunga 🔥',
  'Pack mat kar yaar 🙏',
  'Ye to bluff hai! 🤨',
  'Mauj kar di 👏',
  'Game palat gaya 😱',
  'Rapchik chaal 💃',
  'All in, jai mata di 🚀',
  // Pop-culture one-liners
  'Risk hai toh ishq hai 😤',
  'Control Uday, control 🥵',
  'Ye dukh khatam nahi hota bey 😩',
  'Jalwa hai humara yahan 👑',
  'Chaiye toh aur lo 🤑',
  'Thoda paisa idhar bhi 🙏',
  'Hera Pheri ho gayi 🤯',
  'Aukaat dikha di 😈',
  'Daal mein kuch kaala hai 🤔',
  '25 din mein paisa double 💸',
  'Babu bhaiya, fold! 😅',
  'Itni si baat pe pack? 🙄',
  'Trail aayi hai boss 🐉',
  'Chaal chalu rakho 🎯',
  'Bina dekhe maza hi alag 🕶️',
];

class _Bubble {
  _Bubble(this.id, this.text);
  final int id;
  final String text;
}

/// Wraps a screen and adds a quick-chat button (bottom-left), a compact
/// dropdown picker, and animated floating message bubbles. When a [chat]
/// channel is provided, messages are sent to / received from other players;
/// otherwise bubbles are shown locally only.
class ChatOverlay extends StatefulWidget {
  const ChatOverlay({super.key, required this.child, this.chat});
  final Widget child;
  final TableChat? chat;

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  final List<_Bubble> _bubbles = [];
  final _typeCtrl = TextEditingController();
  int _next = 0;
  int _lastChatId = -1;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.chat?.addListener(_onChat);
  }

  @override
  void dispose() {
    widget.chat?.removeListener(_onChat);
    _typeCtrl.dispose();
    super.dispose();
  }

  void _onChat() {
    final m = widget.chat?.last;
    if (m == null || m.id == _lastChatId) return;
    _lastChatId = m.id;
    Sfx.instance.chat();
    _emit(m.mine ? m.text : '${m.name}: ${m.text}');
  }

  void _emit(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final b = _Bubble(_next++, t);
    setState(() => _bubbles.add(b));
  }

  /// Routes a chosen reaction: over the network if a channel exists (the bubble
  /// then comes back via [_onChat]), otherwise shown locally.
  void _send(String text) {
    if (text.trim().isEmpty) return;
    if (widget.chat != null) {
      widget.chat!.sendText(text);
    } else {
      Sfx.instance.chat();
      _emit(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        widget.child,
        // Floating bubbles rise from bottom-center.
        Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final b in _bubbles)
                  _FloatingBubble(
                    key: ValueKey(b.id),
                    text: b.text,
                    onDone: () => setState(
                        () => _bubbles.removeWhere((x) => x.id == b.id)),
                  ),
              ],
            ),
          ),
        ),
        // Tap-away scrim (transparent so the table stays visible).
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = false),
            ),
          ),
        // Compact dropdown panel above the chat button.
        if (_open)
          Positioned(
            left: 10,
            right: 10,
            bottom: media.viewInsets.bottom + 84,
            child: _ChatPanel(
              typeCtrl: _typeCtrl,
              maxHeight: media.size.height * 0.42,
              onPick: (text) {
                setState(() => _open = false);
                _send(text);
              },
              onSendTyped: () {
                final text = _typeCtrl.text;
                _typeCtrl.clear();
                setState(() => _open = false);
                _send(text);
              },
            ),
          ),
        Positioned(
          left: 14,
          bottom: 84,
          child: FloatingActionButton.small(
            heroTag: 'chat',
            backgroundColor: const Color(0xFF6A1B9A),
            foregroundColor: Colors.white,
            onPressed: () => setState(() => _open = !_open),
            child: Icon(_open ? Icons.close : Icons.emoji_emotions),
          ),
        ),
      ],
    );
  }
}

/// The compact, scrollable dropdown panel of reactions + a type box.
class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.typeCtrl,
    required this.maxHeight,
    required this.onPick,
    required this.onSendTyped,
  });

  final TextEditingController typeCtrl;
  final double maxHeight;
  final void Function(String text) onPick;
  final VoidCallback onSendTyped;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14213D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6A1B9A), width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: typeCtrl,
                      maxLength: 50,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Type a message…',
                        hintStyle: TextStyle(color: Colors.white38),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => onSendTyped(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A)),
                    icon: const Icon(Icons.send),
                    onPressed: onSendTyped,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final e in kQuickEmojis)
                            InkWell(
                              onTap: () => onPick(e),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in kHindiStickers)
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(s,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.white10,
                              labelStyle: const TextStyle(color: Colors.white),
                              onPressed: () => onPick(s),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  const _FloatingBubble(
      {super.key, required this.text, required this.onDone});
  final String text;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2400),
      onEnd: onDone,
      builder: (context, t, child) {
        final opacity = t < 0.15
            ? t / 0.15
            : (t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, -40 * t),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC9A24B)),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}
