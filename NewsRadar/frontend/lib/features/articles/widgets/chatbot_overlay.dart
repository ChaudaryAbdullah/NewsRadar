import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/api_service.dart';
import '../../../core/theme.dart';

// ─── Message model ────────────────────────────────────────────────────────────

class _ChatMessage {
  final bool isUser;
  final String text;
  final List<Map<String, String>> sources;
  final DateTime time;
  bool isLoading;

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.sources = const [],
    this.isLoading = false,
  }) : time = DateTime.now();
}

// ─── Chatbot Overlay ──────────────────────────────────────────────────────────

class ChatbotOverlay extends StatefulWidget {
  final Article article;
  final AnalysisResponse? analysis;
  final VoidCallback onClose;

  const ChatbotOverlay({
    super.key,
    required this.article,
    this.analysis,
    required this.onClose,
  });

  @override
  State<ChatbotOverlay> createState() => _ChatbotOverlayState();
}

class _ChatbotOverlayState extends State<ChatbotOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _slide;

  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api        = ApiService();
  final _sessionId  = 'sess_${DateTime.now().millisecondsSinceEpoch}';

  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  // ── Suggested prompts ──────────────────────────────────────────────────────
  static const _suggestions = [
    'Summarize this article',
    'Is this article reliable?',
    'What are the key claims?',
    'Who are the named entities?',
    'What actions should be taken?',
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.forward();

    // Greeting
    _messages.add(_ChatMessage(
      isUser: false,
      text: 'Hi! I\'m NewsRadar AI. I\'ve read **"${widget.article.title}"** and I\'m ready to answer your questions.\n\nAsk me anything about this article — reliability, claims, context, or more.',
    ));
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildArticleContext() {
    final a = widget.analysis;
    return {
      'title':       widget.article.title,
      'source':      widget.article.source.name,
      'url':         widget.article.url,
      'published_at': widget.article.publishedAt,
      'verdict':     widget.article.status,
      'summary':     a?.insights.summary ?? widget.article.description ?? '',
      'sentiment':   a?.insights.sentiment ?? '',
      'key_claims':  a?.insights.keyClaims ?? <String>[],
      'entities':    a?.insights.namedEntities.map((e) => e.name).toList() ?? <String>[],
    };
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text.trim()));
      _messages.add(_ChatMessage(isUser: false, text: '', isLoading: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final resp = await _api.sendChatMessage(
        message: text.trim(),
        sessionId: _sessionId,
        articleContext: _buildArticleContext(),
      );
      final reply   = resp['reply'] as String? ?? 'Sorry, I could not generate a response.';
      final sources = (resp['sources'] as List? ?? [])
          .map((s) => {'name': s['name'] as String, 'url': s['url'] as String})
          .toList();

      setState(() {
        _messages.removeLast(); // remove loading
        _messages.add(_ChatMessage(isUser: false, text: reply, sources: sources));
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(_ChatMessage(
          isUser: false,
          text: 'Sorry, I couldn\'t reach the AI service. Please check the backend is running.',
        ));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _close() async {
    await _anim.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Positioned.fill(
      child: Column(
        children: [
          // Tap to close backdrop
          Expanded(child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          )),

          // Chat panel
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(_slide),
            child: Container(
              height: min(screenH * 0.72, 620),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -4))],
              ),
              child: Column(children: [
                _ChatHeader(onClose: _close),
                Expanded(child: _MessageList(
                  messages: _messages,
                  scrollCtrl: _scrollCtrl,
                )),
                if (_messages.length == 1) _Suggestions(
                  suggestions: _suggestions,
                  onTap: _send,
                ),
                _InputBar(
                  ctrl: _ctrl,
                  sending: _sending,
                  onSend: _send,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Header ──────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _ChatHeader({required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.accentDeep, AppColors.accent]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NewsRadar AI', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text('Powered by Groq · Llama 3.3 70B', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      ]),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
        onPressed: onClose,
      ),
    ]),
  );
}

// ─── Message List ─────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<_ChatMessage> messages;
  final ScrollController scrollCtrl;
  const _MessageList({required this.messages, required this.scrollCtrl});
  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scrollCtrl,
    padding: const EdgeInsets.all(14),
    itemCount: messages.length,
    itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
  );
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AIAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(delay: 0), const SizedBox(width: 4),
              _Dot(delay: 200), const SizedBox(width: 4),
              _Dot(delay: 400),
            ]),
          ),
        ]),
      );
    }

    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const SizedBox(width: 40),
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentDeep,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4)),
            ),
            child: Text(msg.text, style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.5)),
          )),
        ]),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1);
    }

    // AI message
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AIAvatar(),
        const SizedBox(width: 10),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
              border: Border.all(color: AppColors.divider),
            ),
            child: _MarkdownText(text: msg.text),
          ),
          // Sources
          if (msg.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4,
              children: msg.sources.map((s) => GestureDetector(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentDeep.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.accentDeep.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.link_rounded, size: 10, color: AppColors.accentDeep),
                    const SizedBox(width: 3),
                    Text(s['name'] ?? '', style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
                  ]),
                ),
              )).toList()),
          ],
          Text(_fmt(msg.time), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
        ])),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: -0.05);
  }

  String _fmt(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _AIAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 30, height: 30,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.accentDeep, AppColors.accent]),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
  );
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  Widget build(BuildContext context) => Container(
    width: 6, height: 6,
    decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
  ).animate(onPlay: (c) => c.repeat(reverse: true))
   .fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms);
}

// ─── Markdown text renderer (basic) ──────────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('**') && line.endsWith('**')) {
          return Text(line.replaceAll('**', ''), style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.5));
        }
        if (line.startsWith('- ') || line.startsWith('• ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(color: AppColors.accentDeep, fontSize: 14)),
              Expanded(child: Text(_stripMd(line.substring(2)), style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textPrimary, height: 1.5))),
            ]));
        }
        return Text(_stripMd(line), style: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textPrimary, height: 1.5));
      }).toList(),
    );
  }

  String _stripMd(String s) => s.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m[1]!);
}

// ─── Suggestions row ─────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _Suggestions({required this.suggestions, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      scrollDirection: Axis.horizontal,
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => onTap(suggestions[i]),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(suggestions[i], style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary)),
        ),
      ),
    ),
  );
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final void Function(String) onSend;
  const _InputBar({required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          minLines: 1, maxLines: 4,
          enabled: !sending,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ask about this article...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
            filled: true, fillColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          ),
          onSubmitted: onSend,
        ),
      ),
      const SizedBox(width: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: sending ? AppColors.divider : AppColors.accentDeep,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: sending
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          onPressed: sending ? null : () => onSend(ctrl.text),
        ),
      ),
    ]),
  );
}
