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
  String? _pendingImage;
  String? _pendingFile;
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
    if ((trimmed.isEmpty && _pendingImage == null && _pendingFile == null) ||
        _isLoading) return;

    HapticFeedback.lightImpact();

    String display = trimmed;
    if (_pendingImage != null) display += '\n📷 Image jointe';
    if (_pendingFile  != null) display += '\n📎 Fichier : $_pendingFile';

    final userMsg = TakhiMessage(
      role: 'user',
      content: display.trim(),
      imagePath: _pendingImage,
      fileName:  _pendingFile,
    );

    final String apiText = trimmed.isEmpty
        ? "Analyse cette image / ce fichier et dis-moi si tu vois une panne ou un problème."
        : trimmed;

    final history = _messages
        .where((m) => m != userMsg)
        .map((m) => m.toChatMessage())
        .toList();

    if (!mounted) return;
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _inputCtrl.clear();
      _pendingImage = null;
      _pendingFile  = null;
    });
    _saveHistory();
    _scrollToBottom();

    try {
      final reply = await AuraChatService.sendMessage(
        message: apiText,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Fichiers / Images ─────────────────────────────────────────────────
  void _showAttachMenu() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AttachSheet(
        onCamera:  _pickCamera,
        onGallery: _pickGallery,
        onFile:    _pickFile,
      ),
    );
  }

  Future<void> _pickCamera() async {
    Navigator.pop(context);
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img != null && mounted) setState(() => _pendingImage = img.path);
  }

  Future<void> _pickGallery() async {
    Navigator.pop(context);
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null && mounted) setState(() => _pendingImage = img.path);
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() {
        _pendingFile  = result.files.first.name;
        _pendingImage = result.files.first.path;
      });
    }
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
                if (_pendingImage != null || _pendingFile != null)
                  _buildPendingAttachment(),
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
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: _navBg.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: _white, size: 15),
              ),
            ),
            const SizedBox(width: 12),
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 46,
                height: 46,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TakhiDrive AI',
                    style: TextStyle(
                      color: _white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 7,
                          height: 7,
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
                      const SizedBox(width: 6),
                      Text(
                        _isListening
                            ? '🎤 À l\'écoute...'
                            : _isLoading
                            ? 'En train de répondre...'
                            : 'Assistant intelligent • En ligne',
                        style: TextStyle(
                          color: _white.withOpacity(0.55),
                          fontSize: 11,
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
              width: 3,
              height: h.abs() + 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: (_isLoading || _isListening)
                    ? _purple.withOpacity(0.7 + 0.3 * math.sin(t + i))
                    : _textMuted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[_avatarBot(), const SizedBox(width: 8)],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (msg.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(msg.imagePath!),
                          width: 200,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: _textMuted),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        topLeft:     const Radius.circular(20),
                        topRight:    const Radius.circular(20),
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
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(
                          color: _textMuted.withOpacity(0.55), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            if (isUser) ...[const SizedBox(width: 8), _avatarUser()],
          ],
        ),
      ),
    );
  }

  Widget _avatarBot() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: 34,
        height: 34,
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
      width: 34,
      height: 34,
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _avatarBot(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _glass,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(20),
                topRight:    Radius.circular(20),
                bottomLeft:  Radius.circular(4),
                bottomRight: Radius.circular(20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
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

  Widget _buildPendingAttachment() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          if (_pendingImage != null && _pendingFile == null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_pendingImage!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: _textMuted),
              ),
            )
          else
            const Icon(Icons.insert_drive_file, color: _purpleLight, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _pendingFile ?? 'Image sélectionnée',
              style: const TextStyle(
                  color: _white, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _pendingImage = null;
              _pendingFile  = null;
            }),
            child: const Icon(Icons.close, color: _textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  // ── SUGGESTIONS ───────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            return GestureDetector(
              onTap: () => _sendMessage('${s['icon']} ${s['text']}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _purple.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(color: _purple.withOpacity(0.08), blurRadius: 6),
                  ],
                ),
                child: Text(
                  '${s['icon']} ${s['text']}',
                  style: TextStyle(
                    color: _white.withOpacity(0.82),
                    fontSize: 12,
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
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _navBg.withOpacity(0.97),
        borderRadius: BorderRadius.circular(26),
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
          // 1. Pièce jointe
          GestureDetector(
            onTap: _showAttachMenu,
            child: _iconBtn(Icons.attach_file_rounded, _textMuted),
          ),
          const SizedBox(width: 8),

          // 2. Champ texte
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: _white, fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: _isListening
                    ? '🎤 Parle maintenant...'
                    : 'Pose ta question...',
                hintStyle: TextStyle(
                    color: _textMuted.withOpacity(0.6), fontSize: 14),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),

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
                width: 38,
                height: 38,
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
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Envoyer
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 44,
              height: 44,
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
      width: 38,
      height: 38,
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

// ── Bottom sheet pièce jointe ──────────────────────────────────────────
class _AttachSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFile;

  const _AttachSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
  });

  static const Color _navBg  = Color(0xFF16213E);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _white  = Colors.white;
  static const Color _neon   = Color(0xFF818CF8);
  static const Color _gold   = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      decoration: BoxDecoration(
        color: _navBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _purple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: _purple.withOpacity(0.15), blurRadius: 30),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Joindre un fichier',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: _white),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Caméra',
                  color: _purple,
                  onTap: onCamera),
              _AttachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: _neon,
                  onTap: onGallery),
              _AttachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Fichier',
                  color: _gold,
                  onTap: onFile),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.2), blurRadius: 14),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
