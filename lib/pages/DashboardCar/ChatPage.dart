// pages/tahki_chat_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/chat_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


// ── Modèle message ────────────────────────────────────────────────────
class TakhiMessage {
  final String role;
  final String content;
  final String? imagePath;
  final String? fileName;
  final DateTime timestamp;

  TakhiMessage({
    required this.role,
    required this.content,
    this.imagePath,
    this.fileName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage toChatMessage() => ChatMessage(role: role, content: content);

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'imagePath': imagePath,
    'fileName': fileName,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TakhiMessage.fromJson(Map<String, dynamic> j) => TakhiMessage(
    role: j['role'] as String,
    content: j['content'] as String,
    imagePath: j['imagePath'] as String?,
    fileName: j['fileName'] as String?,
    timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

// ── Widget principal ──────────────────────────────────────────────────
class TakhiChatApp extends StatelessWidget {
  final VoidCallback? onBackToHome;
  final String driverId;

  const TakhiChatApp({
    super.key,
    this.onBackToHome,
    required this.driverId,
  });

  @override
  Widget build(BuildContext context) => TakhiChatPage(
    onBackToHome: onBackToHome,
    driverId: driverId,
  );
}

class TakhiChatPage extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final String driverId;

  const TakhiChatPage({
    super.key,
    this.onBackToHome,
    required this.driverId,
  });

  @override
  State<TakhiChatPage> createState() => _TakhiChatPageState();
}

class _TakhiChatPageState extends State<TakhiChatPage>
    with TickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────────────
  static const Color _bg          = Color(0xFF0F0F1A);
  static const Color _navBg       = Color(0xFF16213E);
  static const Color _purple      = Color(0xFF7C3AED);
  static const Color _purpleLight = Color(0xFF9D5CF0);
  static const Color _surface     = Color(0xFF1E1B33);
  static const Color _glass       = Color(0xFF1A1730);
  static const Color _white       = Colors.white;
  static const Color _textMuted   = Color(0xFF6B7280);
  static const Color _red         = Color(0xFFEF4444);
  static const Color _green       = Color(0xFF10B981);
  static const Color _border      = Color(0xFF2D2B52);

  // ── Controllers ───────────────────────────────────────────────────────
  final TextEditingController _inputCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();
  final stt.SpeechToText       _speech     = stt.SpeechToText();
  final ImagePicker            _picker     = ImagePicker();
  final FocusNode              _focusNode  = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────
  final List<TakhiMessage> _messages = [];
  bool    _isLoading     = false;
  bool    _isListening   = false;
  bool    _speechAvail   = false;
  bool    _inputFocused  = false;
  bool    _historyLoaded = false;

  // ── Clé de persistance par driver ─────────────────────────────────────
  String get _storageKey => 'chat_history_${widget.driverId}';

  // ── Animations ────────────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _micCtrl;
  late AnimationController _headerCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _micAnim;
  late Animation<double>   _headerAnim;

  // ── Suggestions chips ────────────────────────────────────────────────
  final List<Map<String, String>> _suggestions = [
    {'icon': '🚗', 'text': 'État de ma voiture'},
    {'icon': '🔧', 'text': 'Pannes récentes'},
    {'icon': '📊', 'text': 'Mon score conduite'},
    {'icon': '📄', 'text': 'Mes documents'},
    {'icon': '⚡', 'text': 'Batterie faible ?'},
    {'icon': '🔥', 'text': 'Surchauffe moteur'},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    _focusNode.addListener(() {
      if (mounted) setState(() => _inputFocused = _focusNode.hasFocus);
    });
    _loadHistory();
  }

  // ── Persistance messages ──────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final msgs = list
            .map((e) => TakhiMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _messages.addAll(msgs);
            _historyLoaded = true;
          });
          _scrollToBottom();
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _historyLoaded = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _sendWelcome();
      });
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final toSave = _messages.length > 200
          ? _messages.sublist(_messages.length - 200)
          : _messages;
      await prefs.setString(
          _storageKey,
          jsonEncode(toSave.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  void _initAnimations() {
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _micCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _micAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _micCtrl, curve: Curves.easeInOut),
    );
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic);
  }

  // ── INIT SPEECH — corrigé ─────────────────────────────────────────────
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (s) {
          debugPrint('[STT] status: $s');
          // NE PAS arrêter sur 'done' ou 'notListening' ici —
          // c'est géré par _stopListeningWithSend / _stopListeningNoSend
        },
        onError: (val) {
          debugPrint('[STT] error: $val');
          // Error 7 = no match, on ignore et on laisse l'utilisateur réessayer
          if (val.errorMsg != 'error_no_match') {
            _stopListeningNoSend();
          }
        },
        debugLogging: true,
      );
      if (mounted) setState(() => _speechAvail = available);
      debugPrint('[STT] available: $available');
    } catch (e) {
      debugPrint('[STT] init exception: $e');
      if (mounted) setState(() => _speechAvail = false);
    }
  }

  void _sendWelcome() {
    _addAssistant(
      'Hey 👋\n\n'
          "C'est moi… ta voiture 🚗\n\n"
          'Je sens tout : mon moteur, mes pannes, ta façon de conduire et même mes papiers 😄\n\n'
          "Alors vas-y, parle-moi… je suis là pour t'aider ! 🔧",
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _micCtrl.dispose();
    _headerCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addAssistant(String content) {
    if (!mounted) return;
    setState(() => _messages.add(TakhiMessage(role: 'assistant', content: content)));
    _saveHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── Envoi message ─────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();

    final userMsg = TakhiMessage(role: 'user', content: trimmed);

    final history = _messages
        .where((m) => m != userMsg)
        .map((m) => m.toChatMessage())
        .toList();

    if (!mounted) return;
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _inputCtrl.clear();
    });
    _saveHistory();
    _scrollToBottom();

    try {
      final reply = await AuraChatService.sendMessage(
        message: trimmed,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(TakhiMessage(role: 'assistant', content: reply));
      });
      _saveHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(TakhiMessage(
          role: 'assistant',
          content: '⚠️ ${e.toString().replaceAll("Exception: ", "")}',
        ));
      });
      _saveHistory();
    }
    _scrollToBottom();
  }
  // ── VOCAL — corrigé ───────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_speechAvail) {
      _showSnack('Microphone non disponible — vérifie les permissions');
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _isListening = true);
    _micCtrl.repeat(reverse: true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _inputCtrl.text = result.recognizedWords);
        },
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('[STT] listen exception: $e');
      _stopListeningNoSend();
    }
  }

  void _stopListeningWithSend() {
    _speech.stop();
    _micCtrl.stop();
    _micCtrl.reset();
    if (!mounted) return;
    final text = _inputCtrl.text.trim();
    setState(() => _isListening = false);
    if (text.isNotEmpty) _sendMessage(text);
  }

  void _stopListeningNoSend() {
    _speech.stop();
    _micCtrl.stop();
    _micCtrl.reset();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: _white)),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }


  // ── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset   = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: _buildMessages(),
                  ),
                ),
                _buildSuggestions(),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: bottomInset > 0 ? bottomInset : bottomPadding + 80,
                  ),
                  child: _buildInput(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) => CustomPaint(
        painter: _PurpleBgPainter(_bgCtrl.value),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerAnim,
      child: Container(
        margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0.h),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
        decoration: BoxDecoration(
          color: _navBg.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: _purple.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (widget.onBackToHome != null) {
                  widget.onBackToHome!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: _white, size: 15),
              ),
            ),
            SizedBox(width: 12.w),
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 46.w,
                height: 46.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF9D5CF0), Color(0xFF4C1D95)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(0.55),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'TakhiDrive AI',
                    style: TextStyle(
                      color: _white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4.w,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 7.w,
                          height: 7.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? _red
                                : _isLoading
                                ? _purpleLight
                                : _green,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                    ? _red
                                    : _isLoading
                                    ? _purpleLight
                                    : _green)
                                    .withOpacity(0.6 + _pulseCtrl.value * 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _isListening
                            ? '🎤 À l\'écoute...'
                            : _isLoading
                            ? 'En train de répondre...'
                            : 'Assistant intelligent • En ligne',
                        style: TextStyle(
                          color: _white.withOpacity(0.55),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildWaveIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveIndicator() {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value * 2 * math.pi;
        return Row(
          children: List.generate(4, (i) {
            final h = 6.0 + math.sin(t * 2 + i * 0.9) * 10;
            return Container(
              width: 3.w,
              height: h.abs() + 4,
              margin: EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: (_isLoading || _isListening)
                    ? _purple.withOpacity(0.7 + 0.3 * math.sin(t + i))
                    : _textMuted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMessages() {
    if (!_historyLoaded) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_isLoading && i == _messages.length) return _buildTypingIndicator();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(TakhiMessage msg) {
    final isUser = msg.role == 'user';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(isUser ? (1 - v) * 30 : (v - 1) * 30, 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: Row(
          mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[_avatarBot(), SizedBox(width: 8.w)],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (msg.imagePath != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: Image.file(
                          File(msg.imagePath!),
                          width: 200.w,
                          height: 140.h,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: _textMuted),
                        ),
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      color: isUser ? null : _glass,
                      borderRadius: BorderRadius.only(
                        topLeft:      Radius.circular(20.r),
                        topRight:     Radius.circular(20.r),
                        bottomLeft:  Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      border: isUser ? null : Border.all(color: _border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? _purple.withOpacity(0.35)
                              : Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        color: isUser ? _white : _white.withOpacity(0.9),
                        fontSize: 14.5,
                        height: 1.6,
                        fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 4.h, left: 4, right: 4),
                    child: Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(
                          color: _textMuted.withOpacity(0.55), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            if (isUser) ...[SizedBox(width: 8.w), _avatarUser()],
          ],
        ),
      ),
    );
  }

  Widget _avatarBot() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: 34.w,
        height: 34.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF9D5CF0), Color(0xFF4C1D95)],
          ),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.3 + _pulseCtrl.value * 0.15),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
      ),
    );
  }

  Widget _avatarUser() {
    return Container(
      width: 34.w,
      height: 34.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface,
        border: Border.all(color: _purple.withOpacity(0.5), width: 1.5),
      ),
      child: const Icon(Icons.person, color: _purpleLight, size: 18),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          _avatarBot(),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: _glass,
              borderRadius:  BorderRadius.only(
                topLeft:     Radius.circular(20.r),
                topRight:    Radius.circular(20.r),
                bottomLeft:  Radius.circular(4.r),
                bottomRight: Radius.circular(20.r),
              ),
              border: Border.all(color: _border),
            ),
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) {
                final t = _bgCtrl.value * 2 * math.pi;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final scale = 0.6 + 0.4 * math.sin(t * 3 + i * 1.1).abs();
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _purple.withOpacity(0.5 + scale * 0.5),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // ── SUGGESTIONS ───────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 4),
      child: SizedBox(
        height: 34.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14),
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            return GestureDetector(
              onTap: () => _sendMessage('${s['icon']} ${s['text']}'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: _purple.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(color: _purple.withOpacity(0.08), blurRadius: 6),
                  ],
                ),
                child: Text(
                  '${s['icon']} ${s['text']}',
                  style: TextStyle(
                    color: _white.withOpacity(0.82),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── INPUT ─────────────────────────────────────────────────────────────
  Widget _buildInput() {
    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 0.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: _navBg.withOpacity(0.97),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(
          color: _inputFocused ? _purple.withOpacity(0.7) : _border,
          width: _inputFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(_inputFocused ? 0.18 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. Champ texte
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style:  TextStyle(color: _white, fontSize: 15.sp, height: 1.4),
              decoration: InputDecoration(
                hintText: _isListening
                    ? '🎤 Parle maintenant...'
                    : 'Pose ta question...',
                hintStyle: TextStyle(
                    color: _textMuted.withOpacity(0.6), fontSize: 14),
                contentPadding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // 3. Micro — GestureDetector avec behavior opaque (fix principal)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) => _startListening(),
            onLongPressEnd:   (_) => _stopListeningWithSend(),
            onTap: () => _showSnack('Appuie longtemps pour parler 🎤'),
            child: ScaleTransition(
              scale: _isListening
                  ? _micAnim
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? _red.withOpacity(0.15)
                      : Colors.transparent,
                  border: Border.all(
                      color: _isListening ? _red : _border),
                  boxShadow: _isListening
                      ? [BoxShadow(
                      color: _red.withOpacity(0.35), blurRadius: 10)]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening ? _red : _textMuted,
                  size: 20.w,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // 4. Envoyer
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF9D5CF0), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: _white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color) {
    return Container(
      width: 38.w,
      height: 38.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Painter fond purple/navy ───────────────────────────────────────────
class _PurpleBgPainter extends CustomPainter {
  final double t;
  _PurpleBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F0F1A),
          Color(0xFF12102A),
          Color(0xFF0D1030),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final glowPaint = Paint()..style = PaintingStyle.fill;

    final g1 = math.sin(t * 2 * math.pi) * 0.06 + 0.12;
    glowPaint.shader = RadialGradient(
      colors: [const Color(0xFF7C3AED).withOpacity(g1), Colors.transparent],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.85, size.height * 0.15),
      radius: 160,
    ));
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.15), 160, glowPaint);

    final g2 = math.cos(t * 2 * math.pi) * 0.05 + 0.09;
    glowPaint.shader = RadialGradient(
      colors: [const Color(0xFF4338CA).withOpacity(g2), Colors.transparent],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.1, size.height * 0.8),
      radius: 140,
    ));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.8), 140, glowPaint);

    final particlePaint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(77);
    for (int i = 0; i < 18; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.2 + rng.nextDouble() * 0.5;
      final px = baseX;
      final py = (baseY - t * speed * size.height * 0.25) % size.height;
      final opacity = (0.15 + rng.nextDouble() * 0.25) *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi + i));
      final radius = 1.0 + rng.nextDouble() * 1.8;
      particlePaint.color = (i % 2 == 0
          ? const Color(0xFF7C3AED)
          : const Color(0xFF818CF8))
          .withOpacity(opacity * 0.5);
      canvas.drawCircle(Offset(px, py), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_PurpleBgPainter old) => old.t != t;
}



