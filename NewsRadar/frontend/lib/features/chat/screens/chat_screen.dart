import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../../core/theme.dart';
import '../../../shared/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum _Role { user, bot }

class _Msg {
  final String text;
  final _Role role;
  final DateTime time;
  _Msg(this.text, this.role) : time = DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _api = ApiService();
  final _textCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
  final List<_Msg> _msgs = [];

  // UI state
  bool _isTyping = false;
  bool _isListening = false;
  bool _speechReady = false;
  String _liveTranscript = '';

  // Speech
  final SpeechToText _stt = SpeechToText();

  // Animations
  late AnimationController _floatCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _speakCtrl;
  late AnimationController _micPulseCtrl;

  // ── Chips ────────────────────────────────────────────────────────────────
  static const _chips = [
    'Aaj ki top khabrain',
    'Pakistan news',
    'Tech news summary',
    'Ek joke sunao',
    'Fun fact bata do',
    'Mujhe stock market ke baare mein batao',
  ];

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnims();
    _initSpeech();
    _addWelcome();
  }

  void _initAnims() {
    _floatCtrl = AnimationController(vsync: this, duration: 3.seconds)
      ..repeat(reverse: true);
    _blinkCtrl = AnimationController(vsync: this, duration: 150.ms);
    _speakCtrl = AnimationController(vsync: this, duration: 400.ms);
    _micPulseCtrl = AnimationController(vsync: this, duration: 900.ms);

    // auto-blink
    Timer.periodic(4.seconds, (_) {
      if (mounted) _blinkCtrl.forward().then((_) => _blinkCtrl.reverse());
    });
  }

  Future<void> _initSpeech() async {
    final ok = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') _stopListening();
      },
      onError: (e) => _stopListening(),
    );
    if (mounted) setState(() => _speechReady = ok);
  }

  void _addWelcome() {
    Future.delayed(300.ms, () {
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(
        'Assalam o Alaikum! 👋 Main hoon NewsRadar AI.\n\n'
        '🎙️ Mic dabao aur bolo — main sunta hoon!\n'
        'English ya Roman Urdu — dono mein jawab dunga. 🇵🇰',
        _Role.bot,
      )));
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    _speakCtrl.dispose();
    _micPulseCtrl.dispose();
    _textCtrl.dispose();
    _scroll.dispose();
    _stt.stop();
    super.dispose();
  }

  // ── Voice ─────────────────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    if (_isListening) {
      await _stt.stop();
      _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      _showSnack('Mic permission chahiye! Settings mein allow karo.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _isListening = true; _liveTranscript = ''; });
    _micPulseCtrl.repeat(reverse: true);
    _textCtrl.clear();

    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _liveTranscript = result.recognizedWords;
      _textCtrl.text = _liveTranscript;
    });
    if (result.finalResult && _liveTranscript.trim().isNotEmpty) {
      _stopListening();
      _send(_liveTranscript.trim());
    }
  }

  void _stopListening() {
    _stt.stop();
    _micPulseCtrl.stop();
    _micPulseCtrl.reset();
    if (mounted) setState(() { _isListening = false; _liveTranscript = ''; });
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _msgs.add(_Msg(text, _Role.user));
      _isTyping = true;
    });
    _scrollBottom();

    try {
      final res = await _api.sendChatMessage(
        message: text,
        sessionId: _sessionId,
      );
      final reply = res['reply'] as String? ?? 'Jawab nahi mila. Phir try karo.';
      if (!mounted) return;
      setState(() { _isTyping = false; _msgs.add(_Msg(reply, _Role.bot)); });
      _speakCtrl.forward().then((_) =>
          Future.delayed(2.seconds, () => mounted ? _speakCtrl.reverse() : null));
    } catch (_) {
      if (!mounted) return;
      setState(() { _isTyping = false; _msgs.add(_Msg(_fallback(text), _Role.bot)); });
    }
    _scrollBottom();
  }

  String _fallback(String t) {
    final q = t.toLowerCase();
    if (RegExp(r'salam|hello|hi\b|assalam').hasMatch(q))
      return 'Wa Alaikum Assalam! 👋 Server se connection nahi, lekin main yahan hoon!';
    if (RegExp(r'joke|mazak|funny').hasMatch(q))
      return 'Haha! 😂 Editor ne kaha "Short karo khabar!" — Journalist ne delete kar di sari khabar aur likha: "Kuch nahi hua." 😂';
    if (RegExp(r'fun fact|amazing|interesting').hasMatch(q))
      return 'Fun fact: Octopuses ke 3 hearts hote hain aur unka blood BLUE hota hai! 🐙';
    if (RegExp(r'pakistan|karachi|lahore').hasMatch(q))
      return 'Pakistan 🇵🇰 ke baare mein — backend online hone pe real data milega. Abhi server unreachable hai.';
    return 'Backend se connection nahi ho raha. Server check karo aur retry karo! 🔄';
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: 300.ms, curve: Curves.easeOut,
    );
  });

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: 2.seconds));

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: _chatList()),
          _inputBar(),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      // Floating bot icon
      AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -sin(_floatCtrl.value * pi) * 3),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF004E9F)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF004E9F).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NewsRadar AI', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF004E9F))),
          Row(children: [
            Container(width: 7, height: 7,
              decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle))
                .animate(onPlay: (c) => c.repeat()).fade(duration: 1200.ms),
            const SizedBox(width: 5),
            Text(
              _isListening ? 'Sun raha hoon... 🎙️' : _isTyping ? 'Soch raha hoon...' : 'Online · Groq AI · Mic Ready',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ]),
        ],
      )),
      IconButton(
        icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textMuted, size: 22),
        onPressed: () => setState(() { _msgs.clear(); _addWelcome(); }),
        tooltip: 'Clear chat',
      ),
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    ]),
  );

  // ── Chat List ──────────────────────────────────────────────────────────────
  Widget _chatList() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    itemCount: 1 + _msgs.length + (_isTyping ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == 0) return _welcomeAvatar();
      final msgI = i - 1;
      if (msgI == _msgs.length && _isTyping) return _typingBubble();
      return _bubble(_msgs[msgI], msgI);
    },
  );

  // ── Welcome Avatar (top of chat) ──────────────────────────────────────────
  Widget _welcomeAvatar() => Column(children: [
    const SizedBox(height: 8),
    // Animated bot
    AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _blinkCtrl, _speakCtrl]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, -sin(_floatCtrl.value * pi) * 5),
        child: Stack(alignment: Alignment.center, children: [
          // Pulse ring
          Container(width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF004E9F).withOpacity(0.25 * (1 - _floatCtrl.value)),
                width: 2,
              ),
            )),
          CustomPaint(
            size: const Size(70, 70),
            painter: _BotPainter(blink: _blinkCtrl.value, speak: _speakCtrl.value),
          ),
        ]),
      ),
    ),
    const SizedBox(height: 10),
    Text('NewsRadar AI', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1B1C1C))),
    const SizedBox(height: 4),
    Text('Bolو ya type karo — main dono samajhta hoon 🇵🇰',
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
      textAlign: TextAlign.center),
    const SizedBox(height: 12),
    // Chips
    SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_chips[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC1C6D5).withOpacity(0.7)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Text(_chips[i], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF414753))),
          ),
        ),
      ),
    ),
    const SizedBox(height: 16),
  ]);

  // ── Bubble ────────────────────────────────────────────────────────────────
  Widget _bubble(_Msg msg, int i) {
    final isUser = msg.role == _Role.user;
    final time = '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF004E9F)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                gradient: isUser ? const LinearGradient(
                  colors: [Color(0xFF0066CC), Color(0xFF004E9F)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ) : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(
                  color: isUser ? const Color(0xFF004E9F).withOpacity(0.3) : Colors.black.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, 3),
                )],
                border: isUser ? null : Border.all(color: const Color(0xFFC1C6D5).withOpacity(0.4)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text, style: GoogleFonts.inter(
                    fontSize: 14, height: 1.55,
                    color: isUser ? Colors.white : const Color(0xFF1B1C1C),
                  )),
                  const SizedBox(height: 4),
                  Text(time, style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isUser ? Colors.white.withOpacity(0.6) : AppColors.textMuted,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: min(i * 40, 150)))
        .fadeIn(duration: 280.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }

  // ── Typing Bubble ─────────────────────────────────────────────────────────
  Widget _typingBubble() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(right: 8, bottom: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF004E9F)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: const Color(0xFFC1C6D5).withOpacity(0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [0, 1, 2].map((i) =>
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7, height: 7,
              decoration: BoxDecoration(color: const Color(0xFF004E9F).withOpacity(0.4), shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat())
                .moveY(begin: 0, end: -5, delay: Duration(milliseconds: i * 150), duration: 400.ms, curve: Curves.easeInOut)
                .then().moveY(begin: -5, end: 0, duration: 400.ms),
          ).toList()),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 200.ms);

  // ── Input Bar ─────────────────────────────────────────────────────────────
  Widget _inputBar() {
    final isActive = _isListening;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border(top: BorderSide(color: const Color(0xFFC1C6D5).withOpacity(0.3))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Live transcript (shown while listening)
        if (_isListening && _liveTranscript.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFAE2F34).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFAE2F34).withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: Color(0xFFAE2F34), shape: BoxShape.circle))
                .animate(onPlay: (c) => c.repeat()).fade(duration: 600.ms),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _liveTranscript,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1B1C1C), fontStyle: FontStyle.italic),
              )),
            ]),
          ),

        // Input row
        Row(children: [
          // Big mic button
          AnimatedBuilder(
            animation: _micPulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: isActive ? 1.0 + _micPulseCtrl.value * 0.12 : 1.0,
              child: GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: isActive
                      ? [const Color(0xFFAE2F34), const Color(0xFF8B0000)]
                      : [const Color(0xFF0066CC), const Color(0xFF004E9F)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: (isActive ? const Color(0xFFAE2F34) : const Color(0xFF004E9F)).withOpacity(0.45),
                      blurRadius: isActive ? 16 : 10,
                      offset: const Offset(0, 4),
                    )],
                  ),
                  child: Icon(
                    isActive ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFC1C6D5).withOpacity(0.7)),
                boxShadow: [BoxShadow(color: const Color(0xFF004E9F).withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 3, minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1C1C)),
                    decoration: InputDecoration(
                      hintText: isActive ? 'Bol raha hoon...' : 'Ya type karo... 💬',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                // Send button
                GestureDetector(
                  onTap: () => _send(_textCtrl.text),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF004E9F)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF004E9F).withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 4),
        Text(
          _isListening ? '🎙️ Bolna band karo — khud bhej dunga' : 'Mic dabao aur bolو ya text likho',
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted.withOpacity(0.8)),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOT PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _BotPainter extends CustomPainter {
  final double blink, speak;
  _BotPainter({required this.blink, required this.speak});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*.1, h*.25, w*.8, h*.6), Radius.circular(w*.18)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF004E9F)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)
        .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Antenna
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.38, h*.04, w*.24, h*.25), Radius.circular(5)),
      Paint()..color = const Color(0xFF0066CC));
    canvas.drawCircle(Offset(w*.5, h*.08), w*.075,
      Paint()..color = const Color(0xFFAAC7FF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Face screen
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*.15, h*.32, w*.7, h*.43), Radius.circular(w*.11)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFF1A7DE8), Color(0xFF003D8C)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(Rect.fromLTWH(w*.15, h*.32, w*.7, h*.43)),
    );

    // Eyes
    void eye(double cx, double cy) {
      final ey = (w*.085) * (1 - blink * .92);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx,cy), width: w*.13, height: ey*2), Paint()..color=Colors.white);
      if (ey > 2) {
        canvas.drawCircle(Offset(cx+1, cy), w*.05, Paint()..color=const Color(0xFF004E9F));
        canvas.drawCircle(Offset(cx+2.5, cy-2), w*.018, Paint()..color=Colors.white);
      }
    }
    eye(w*.34, h*.52); eye(w*.66, h*.52);

    // Mouth / speak bars
    if (speak < 0.25) {
      final p = Path()..moveTo(w*.34, h*.68)..quadraticBezierTo(w*.5, h*.76, w*.66, h*.68);
      canvas.drawPath(p, Paint()..color=Colors.white.withOpacity(.5)..style=PaintingStyle.stroke
        ..strokeWidth=2.2..strokeCap=StrokeCap.round);
    } else {
      final hts = [.06, .10, .13, .10, .06];
      for (int i=0; i<5; i++) {
        final bh = hts[i]*h*(0.5 + speak*.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*(0.36+i*.07), h*.71), width: 2.5, height: bh), const Radius.circular(2)),
          Paint()..color=Colors.white.withOpacity(.65));
      }
    }

    // Ears + LED
    canvas.drawCircle(Offset(w*.1, h*.53), w*.055, Paint()..color=const Color(0xFF0052B3));
    canvas.drawCircle(Offset(w*.9, h*.53), w*.055, Paint()..color=const Color(0xFF0052B3));
    canvas.drawCircle(Offset(w*.63, h*.77), w*.03, Paint()..color=const Color(0xFF78DC77));
  }

  @override bool shouldRepaint(_BotPainter o) => o.blink != blink || o.speak != speak;
}
