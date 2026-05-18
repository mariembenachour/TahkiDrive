import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../../services/notification_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  PALETTE  — Premium Dark × Neon Accents
// ═══════════════════════════════════════════════════════════════════════════════
const _ink        = Color(0xFF04000A);
const _surface    = Color(0xFF0D0118);
const _glass      = Color(0x0DFFFFFF);
const _glassHi    = Color(0x18FFFFFF);

const _neonRed    = Color(0xFFFF2D55);
const _neonPurple = Color(0xFFBF5AF2);
const _neonBlue   = Color(0xFF0A84FF);
const _neonGreen  = Color(0xFF30D158);
const _neonOrange = Color(0xFFFF9F0A);
const _neonCyan   = Color(0xFF5AC8FA);

const _redGlow    = Color(0x44FF2D55);
const _purpGlow   = Color(0x33BF5AF2);

const _labelHi    = Color(0xFFF2F2F7);
const _labelMid   = Color(0xFF8E8E93);
const _labelLo    = Color(0xFF3A3A3C);

// ═══════════════════════════════════════════════════════════════════════════════
class DailyReportPage extends StatefulWidget {
  final String cin;
  final String? date;
  const DailyReportPage({super.key, required this.cin, this.date});
  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage>
    with TickerProviderStateMixin {

  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _muted   = true;
  int  _currentBubbleIndex = -1;
  late AnimationController _avatarSlideCtrl;
  late Animation<Offset>   _avatarSlide;

  // ── Video ──────────────────────────────────────────────────────────────────
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  // ── Animations globales ────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;
  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;
  late AnimationController _floatCtrl;
  late Animation<double>   _float;
  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmer;

  // ── Carousel ──────────────────────────────────────────────────────────────
  final PageController _carouselCtrl = PageController(viewportFraction: 0.82);
  int _carouselPage = 0;

  // ── Bars ──────────────────────────────────────────────────────────────────
  final List<AnimationController> _barCtrl = [];
  final List<Animation<double>>   _barAnim = [];

  // ── Bubbles ───────────────────────────────────────────────────────────────
  final List<AnimationController> _bubbleCtrl  = [];
  final List<Animation<double>>   _bubbleFade  = [];
  final List<Animation<Offset>>   _bubbleSlide = [];
  final List<String>              _bubbleTexts = [];
  final List<String>              _bubbleTags  = [];

  // ── Card stagger ──────────────────────────────────────────────────────────
  final List<AnimationController> _cardCtrl = [];
  final List<Animation<double>>   _cardAnim = [];

  // ── Event cards ───────────────────────────────────────────────────────────
  final List<AnimationController> _eventCardCtrl = [];
  final List<Animation<double>>   _eventCardAnim = [];

  // ── Trajets ───────────────────────────────────────────────────────────────
  int _selectedPathIndex = 0;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _setupAnimations();
    _loadReport();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.asset('video/avatar.mp4')
      ..initialize().then((_) {
        _videoCtrl
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        if (mounted) setState(() => _videoReady = true);
      }).catchError((Object e) {
        debugPrint('❌ Video init error: $e');
      });
    _videoCtrl.addListener(() {
      if (_videoCtrl.value.hasError) {
        debugPrint('❌ Video error: ${_videoCtrl.value.errorDescription}');
      }
    });
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) {
      NotificationService.stopSpeaking();
      setState(() => _currentBubbleIndex = -1);
    } else {
      setState(() => _currentBubbleIndex = -1);
      _speakAll();
    }
  }

  void _setupAnimations() {
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.7, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.8, curve: Curves.easeOutCubic)));
    _entryCtrl.forward();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutQuart);

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4500))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -4, end: 4)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    _avatarSlideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _avatarSlide = Tween<Offset>(
        begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _avatarSlideCtrl, curve: Curves.easeOutCubic));
    _avatarSlideCtrl.forward();
  }

  void _buildBubbles(Map<String, dynamic> r) {
    _bubbleTexts.clear();
    _bubbleTags.clear();

    final List<List<String>> pairs = [
      [r['intro']?.toString()          ?? '', 'intro'],
      [r['alerts_summary']?.toString() ?? '', 'alert'],
      [r['score_comment']?.toString()  ?? '', 'score'],
      [r['tip']?.toString()            ?? '', 'tip'],
      [r['outro']?.toString()          ?? '', 'outro'],
    ];
    for (final p in pairs) {
      if (p[0].isNotEmpty) {
        if (p[1] == 'alert' && (r['events_count'] ?? 0) == 0) continue;
        _bubbleTexts.add(p[0]);
        _bubbleTags.add(p[1]);
      }
    }

    for (var c in _bubbleCtrl) c.dispose();
    _bubbleCtrl.clear(); _bubbleFade.clear(); _bubbleSlide.clear();

    for (int i = 0; i < _bubbleTexts.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 800));
      _bubbleCtrl.add(ctrl);
      _bubbleFade.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _bubbleSlide.add(Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      Future.delayed(Duration(milliseconds: 500 + i * 700), () {
        if (mounted) ctrl.forward();
      });
    }

    for (var c in _barCtrl) c.dispose();
    _barCtrl.clear(); _barAnim.clear();
    for (int i = 0; i < 5; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200));
      _barCtrl.add(ctrl);
      _barAnim.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutQuart));
      Future.delayed(Duration(milliseconds: 900 + i * 120), () {
        if (mounted) ctrl.forward();
      });
    }

    for (var c in _cardCtrl) c.dispose();
    _cardCtrl.clear(); _cardAnim.clear();
    for (int i = 0; i < 8; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));
      _cardCtrl.add(ctrl);
      _cardAnim.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack));
      Future.delayed(Duration(milliseconds: 700 + i * 130), () {
        if (mounted) ctrl.forward();
      });
    }

    final events = (r['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (var c in _eventCardCtrl) c.dispose();
    _eventCardCtrl.clear(); _eventCardAnim.clear();
    for (int i = 0; i < events.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _eventCardCtrl.add(ctrl);
      _eventCardAnim.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
      Future.delayed(Duration(milliseconds: 1000 + i * 100), () {
        if (mounted) ctrl.forward();
      });
    }

    _ringCtrl.forward();
  }

  Future<void> _loadReport() async {
    final report = await NotificationService.getDailyReport(
        widget.cin, date: widget.date);
    if (mounted) setState(() {
      _report = report; _loading = false;
      if (report != null) _buildBubbles(report);
    });
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
    _pulseCtrl.dispose(); _entryCtrl.dispose();
    _ringCtrl.dispose();  _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _carouselCtrl.dispose();
    _avatarSlideCtrl.dispose();
    for (var c in _bubbleCtrl)    c.dispose();
    for (var c in _barCtrl)       c.dispose();
    for (var c in _cardCtrl)      c.dispose();
    for (var c in _eventCardCtrl) c.dispose();
    NotificationService.stopSpeaking();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD ROOT
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final vidH = size.height * 0.38;

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0012), Color(0xFF04000A)],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(child: _AmbientOrbs(pulse: _pulse)),
        // Bulle avatar flottante — entre depuis la droite
        Positioned(
          top: 100,
          right: 16,
          child: SlideTransition(
            position: _avatarSlide,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulse, _floatCtrl]),
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _float.value),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _neonPurple.withOpacity(0.35),
                        _neonRed.withOpacity(0.25),
                      ],
                    ),
                    border: Border.all(
                      color: _neonPurple.withOpacity(0.55 + 0.25 * _pulse.value),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _neonPurple.withOpacity(0.25 + 0.15 * _pulse.value),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _neonRed.withOpacity(0.12),
                        blurRadius: 40,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _videoReady
                        ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width:  _videoCtrl.value.size.width,
                        height: _videoCtrl.value.size.height,
                        child:  VideoPlayer(_videoCtrl),
                      ),
                    )
                        : AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A0030),
                              Color.lerp(
                                const Color(0xFF2D0050),
                                const Color(0xFF3D0015),
                                _pulse.value,
                              )!,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.directions_car_rounded,
                            color: _neonPurple,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent, Colors.transparent,
                  _ink.withOpacity(0.15), _ink.withOpacity(0.70), _ink, _ink,
                ],
                stops: const [0.0, 0.40, 0.58, 0.78, 0.92, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: Column(children: [
                _buildAppBar(),
                Expanded(
                  child: _loading
                      ? _buildLoader()
                      : _report == null
                      ? _buildEmpty()
                      : _buildScrollBody(vidH, size),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(children: [
        _GlassButton(
          onTap: () => Navigator.pop(context),
          pulse: _pulse,
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _labelHi, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RAPPORT',
                    style: TextStyle(
                      color: _labelHi, fontSize: 17, fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      shadows: [Shadow(color: _neonRed.withOpacity(0.35 + 0.25 * _pulse.value), blurRadius: 20)],
                    )),
                Text('DU JOUR',
                    style: TextStyle(
                      color: _neonPurple.withOpacity(0.7 + 0.3 * _pulse.value),
                      fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 3.5,
                    )),
              ],
            ),
          ),
        ),
        _GlassButton(
          onTap: _toggleMute,
          pulse: _pulse,
          accentColor: _muted ? null : _neonRed,
          child: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: _muted ? _labelMid : _neonRed, size: 15,
          ),
        ),
      ]),
    );
  }

  Widget _buildLoader() => Center(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(
              color: _neonPurple.withOpacity(0.6 + 0.4 * _pulse.value),
              strokeWidth: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text('Chargement…',
              style: TextStyle(
                  color: _labelMid.withOpacity(0.5 + 0.5 * _pulse.value),
                  fontSize: 12, letterSpacing: 1.2)),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.directions_car_rounded, color: _labelLo, size: 40),
      const SizedBox(height: 14),
      const Text('Aucun rapport disponible',
          style: TextStyle(color: _labelMid, fontSize: 14, letterSpacing: 0.2)),
    ]),
  );

  // ── SCROLL BODY ────────────────────────────────────────────────────────────
  Widget _buildScrollBody(double vidH, Size size) {
    final events      = (_report!['events']      as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pattern     = _report!['danger_pattern'] as Map<String, dynamic>?;
    final diagnostics = (_report!['diagnostics']  as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pathsToday  = (_report!['paths']         as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const SizedBox(height: 120),

        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: _buildHeroSection(),
        ),
        const SizedBox(height: 28),

        _SectionLabel(label: 'MÉTRIQUES', pulse: _pulse),
        const SizedBox(height: 14),
        _buildCarousel(),
        const SizedBox(height: 28),

        // ── TRAJETS ────────────────────────────────────────────────────────
        if (pathsToday.isNotEmpty) ...[
          _SectionLabel(label: 'NOS TRAJETS', pulse: _pulse),
          const SizedBox(height: 14),
          _buildPathsSection(pathsToday),
          const SizedBox(height: 28),
        ],

        if (_bubbleTexts.isNotEmpty) ...[
          _SectionLabel(label: 'CE QUE JE TE DIS', pulse: _pulse),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildInsightsColumn(),
          ),
          const SizedBox(height: 28),
        ],

        // ── PANNES — grille 2×2 ────────────────────────────────────────────
        if (diagnostics.isNotEmpty) ...[
          _SectionLabel(label: 'MES PETITS SOUCIS', pulse: _pulse),
          const SizedBox(height: 14),
          _buildPannesGrid(diagnostics),
          const SizedBox(height: 28),
        ],

        if (pattern != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildDangerPatternCard(pattern),
          ),
          const SizedBox(height: 28),
        ],

        if (events.isNotEmpty) ...[
          _SectionLabel(label: 'ÉVÉNEMENTS', pulse: _pulse),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildEventsSection(events),
          ),
          const SizedBox(height: 28),
        ],

        _SectionLabel(label: 'DÉTAIL PAR CATÉGORIE', pulse: _pulse),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildCategoryBars(),
        ),
        const SizedBox(height: 28),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildBottomActions(),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SECTION TRAJETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPathsSection(List<Map<String, dynamic>> paths) {
    if (paths.isEmpty) return const SizedBox();
    final path = paths[_selectedPathIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Onglets trajets — avec adresse début/fin ──────────────────────
        if (paths.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(paths.length, (i) {
                  final p      = paths[i];
                  final active = i == _selectedPathIndex;
                  // Adresses pré-résolues stockées dans le path (facultatif)
                  final startAddr = p['start_address']?.toString();
                  final endAddr   = p['end_address']?.toString();
                  final tabLabel  = (startAddr != null && endAddr != null)
                      ? '$startAddr → $endAddr'
                      : '${p['begin']} → ${p['end']}';

                  return GestureDetector(
                    onTap: () => setState(() => _selectedPathIndex = i),
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: active
                              ? LinearGradient(colors: [
                            _neonRed.withOpacity(0.25),
                            _neonPurple.withOpacity(0.15),
                          ])
                              : null,
                          color: active ? null : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: active
                                ? _neonRed.withOpacity(0.5 + 0.2 * _pulse.value)
                                : Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: active
                              ? [BoxShadow(
                              color: _neonRed.withOpacity(0.15),
                              blurRadius: 12)]
                              : null,
                        ),
                        child: Row(children: [
                          Icon(
                            Icons.route_rounded,
                            size: 12,
                            color: active ? _neonRed : _labelMid,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trajet ${i + 1}',
                                  style: TextStyle(
                                    color: active ? _labelHi : _labelMid,
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                  )),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  tabLabel,
                                  style: TextStyle(
                                    color: active ? _neonRed : _labelLo,
                                    fontSize: 9, letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

        if (paths.length > 1) const SizedBox(height: 14),

        // ── _PathMapCard contient maintenant aussi la timeline ─────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _PathMapCard(
            path: path,
            pulse: _pulse,
          ),
        ),
      ],
    );
  }

  // ── HERO SECTION ───────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    final score = (_report!['score_today'] ?? 0) as num;
    final label = score >= 80 ? 'Excellent' : score >= 60 ? 'Correct' : 'À améliorer';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_ringAnim, _pulse, _shimmer]),
              builder: (_, __) => SizedBox(
                width: 100, height: 100,
                child: CustomPaint(
                  painter: _PremiumRingPainter(
                    progress: _ringAnim.value * score / 100,
                    colorA: _neonPurple, colorB: _neonPurple,
                    shimmer: _shimmer.value, pulseValue: _pulse.value,
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_neonPurple, _neonCyan],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: Text('${score.toInt()}',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 26,
                              fontWeight: FontWeight.w800, letterSpacing: -1, height: 1,
                            )),
                      ),
                      Text('/100', style: TextStyle(color: _labelMid, fontSize: 8, letterSpacing: 1)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_neonRed.withOpacity(0.18), _neonPurple.withOpacity(0.18)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color.lerp(_neonRed, _neonPurple, 0.5)!
                        .withOpacity(0.45 + 0.15 * _pulse.value),
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_neonRed, _neonPurple],
                  ).createShader(bounds),
                  child: Text(label,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5,
                      )),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(
                _bubbleTexts.length.clamp(0, 2), (i) {
              if (i >= _bubbleFade.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeTransition(
                  opacity: _bubbleFade[i],
                  child: SlideTransition(
                    position: _bubbleSlide[i],
                    child: i == 0
                        ? Transform.translate(
                      offset: const Offset(-100, -80),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _InsightBubble(
                              text: _bubbleTexts[i],
                              pulse: _pulse,
                              compact: false,
                              tag: i < _bubbleTags.length ? _bubbleTags[i] : '',
                            ),
                            Positioned(
                              right: -8,
                              bottom: 12,
                              child: CustomPaint(
                                size: const Size(10, 12),
                                painter: _BubbleTailPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        : Transform.translate(
                      offset: const Offset(0, -30),
                      child: _InsightBubble(
                        text: _bubbleTexts[i], pulse: _pulse, compact: false,
                        tag: i < _bubbleTags.length ? _bubbleTags[i] : '',
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsColumn() {
    return Column(
      children: List.generate(_bubbleTexts.length, (i) {
        if (i >= _bubbleFade.length) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeTransition(
            opacity: _bubbleFade[i],
            child: SlideTransition(
              position: _bubbleSlide[i],
              child: _InsightBubble(
                text: _bubbleTexts[i], pulse: _pulse,
                tag: i < _bubbleTags.length ? _bubbleTags[i] : '',
                isActive: _currentBubbleIndex == i && !_muted,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PANNES — Grille 2×2 avec expand
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPannesGrid(List<Map<String, dynamic>> diagnostics) {
    if (diagnostics.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: diagnostics.length,
        itemBuilder: (ctx, i) {
          final diag = diagnostics[i];
          final anim = i < _eventCardAnim.length
              ? _eventCardAnim[i] : kAlwaysCompleteAnimation;
          return AnimatedBuilder(
            animation: Listenable.merge([anim, _pulse]),
            builder: (_, __) => ScaleTransition(
              scale: anim,
              child: _DiagSquareCard(diag: diag, pulse: _pulse),
            ),
          );
        },
      ),
    );
  }

  // ── CAROUSEL ──────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    final score  = (_report!['score_today']    ?? 0) as num;
    final events = (_report!['events_count']   ?? 0) as num;
    final km     = _report!['km_parcourus'];
    final duree  = _report!['duree_conduite']  as String?;
    final notifs = (_report!['notif_count']    ?? 0) as num;

    final cards = <_CardData>[
      _CardData(icon: Icons.speed_rounded, label: 'VITESSE',
          value: '${_report!['score_vitesse'] ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_vitesse'] ?? 100) as int)),
      _CardData(icon: Icons.warning_amber_rounded, label: 'ALERTES',
          value: '${events.toInt()}', unit: events == 0 ? '✦' : 'evt',
          color: events == 0 ? _neonGreen : _neonRed),
      _CardData(icon: Icons.local_fire_department_rounded, label: 'FREINAGE',
          value: '${_report!['score_freinage'] ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_freinage'] ?? 100) as int)),
      _CardData(icon: Icons.remove_red_eye_rounded, label: 'VIGILANCE',
          value: '${_report!['score_vigilance'] ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_vigilance'] ?? 100) as int)),
      if (km != null)
        _CardData(icon: Icons.route_rounded, label: 'KM PARCOURUS',
            value: '${(km as num).toStringAsFixed(0)}', unit: 'km',
            color: _neonBlue),
      if (duree != null)
        _CardData(icon: Icons.timer_rounded, label: 'DURÉE',
            value: duree, unit: '', color: _neonOrange),
      _CardData(icon: Icons.notifications_rounded, label: 'NOTIFS',
          value: '${notifs.toInt()}', unit: notifs == 0 ? '✦' : 'notif',
          color: notifs == 0 ? _neonGreen : _neonOrange),
    ];

    return Column(children: [
      SizedBox(
        height: 150,
        child: PageView.builder(
          controller: _carouselCtrl,
          itemCount: cards.length,
          onPageChanged: (p) => setState(() => _carouselPage = p),
          itemBuilder: (ctx, i) {
            final d    = cards[i];
            final anim = i < _cardAnim.length ? _cardAnim[i] : kAlwaysCompleteAnimation;
            return AnimatedBuilder(
              animation: Listenable.merge([anim, _pulse, _shimmer]),
              builder: (_, __) => ScaleTransition(
                scale: anim,
                child: Transform.scale(
                  scale: i == _carouselPage ? 1.0 : 0.93,
                  child: _PremiumCard(
                    data: d, pulse: _pulse, shimmer: _shimmer,
                    active: i == _carouselPage,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(cards.length, (i) {
          final active = i == _carouselPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 5, height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active ? _neonRed : _labelLo,
              boxShadow: active
                  ? [BoxShadow(color: _neonRed.withOpacity(0.7), blurRadius: 8)] : null,
            ),
          );
        }),
      ),
    ]);
  }

  // ── ALERTE COMBINÉE ────────────────────────────────────────────────────────
  Widget _buildDangerPatternCard(Map<String, dynamic> pattern) {
    final carVoice = pattern['car_voice']?.toString()
        ?? pattern['message']?.toString() ?? '';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  _neonOrange.withOpacity(0.12),
                  _neonRed.withOpacity(0.08),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: _neonOrange.withOpacity(0.35 + 0.15 * _pulse.value)),
              boxShadow: [
                BoxShadow(
                    color: _neonOrange.withOpacity(0.10 + 0.05 * _pulse.value),
                    blurRadius: 24, spreadRadius: -4),
              ],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonOrange.withOpacity(0.15),
                  border: Border.all(color: _neonOrange.withOpacity(0.5)),
                ),
                child: const Icon(Icons.warning_rounded, color: _neonOrange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('😰 Oo mon conducteur...',
                        style: TextStyle(
                          color: _neonOrange, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 1,
                        )),
                    const SizedBox(height: 3),
                    Text(pattern['pattern']?.toString() ?? '',
                        style: const TextStyle(
                          color: _labelHi, fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                    if (carVoice.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(carVoice,
                          style: const TextStyle(
                            color: _labelMid, fontSize: 11,
                            height: 1.4, fontStyle: FontStyle.italic,
                          )),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── ÉVÉNEMENTS ─────────────────────────────────────────────────────────────
  Widget _buildEventsSection(List<Map<String, dynamic>> events) {
    return Column(
      children: List.generate(events.length, (i) {
        final ev       = events[i];
        final label    = ev['label']?.toString()      ?? '';
        final count    = ev['count'] as num?          ?? 1;
        final colorHex = ev['color']?.toString()      ?? '#FF6D00';
        final isCrit   = ev['is_critical'] == true;
        final carVoice = ev['car_voice']?.toString()  ?? '';

        Color accent;
        try { accent = Color(int.parse(colorHex.replaceFirst('#', '0xFF'))); }
        catch (_) { accent = _neonPurple; }

        final anim = i < _eventCardAnim.length
            ? _eventCardAnim[i] : kAlwaysCompleteAnimation;

        return AnimatedBuilder(
          animation: Listenable.merge([anim, _pulse]),
          builder: (_, __) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            accent.withOpacity(0.08),
                            Colors.white.withOpacity(0.03),
                          ],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        ),
                        border: Border.all(
                            color: accent.withOpacity(0.20 + 0.10 * _pulse.value)),
                      ),
                      child: Row(children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withOpacity(0.12),
                                border: Border.all(color: accent.withOpacity(0.35)),
                              ),
                              child: Icon(
                                isCrit ? Icons.error_rounded : Icons.notifications_rounded,
                                color: accent, size: 18,
                              ),
                            ),
                            if (count > 1)
                              Positioned(
                                top: -4, right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('×${count.toInt()}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 8,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(label,
                                    style: const TextStyle(
                                      color: _labelHi, fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                                if (isCrit) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _neonRed.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('CRITIQUE',
                                        style: TextStyle(
                                            color: _neonRed, fontSize: 7,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5)),
                                  ),
                                ],
                              ]),
                              if (carVoice.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(carVoice,
                                    style: const TextStyle(
                                      color: _labelMid, fontSize: 10,
                                      height: 1.3, fontStyle: FontStyle.italic,
                                    )),
                              ],
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── CATEGORY BARS ─────────────────────────────────────────────────────────
  Widget _buildCategoryBars() {
    final cats = [
      ('Vitesse',   _report!['score_vitesse']   ?? 100, _neonBlue),
      ('Freinage',  _report!['score_freinage']  ?? 100, _neonPurple),
      ('Vigilance', _report!['score_vigilance'] ?? 100, _neonRed),
      ('Fatigue',   _report!['score_fatigue']   ?? 100, _neonOrange),
      ('Sécurité',  _report!['score_securite']  ?? 100, _neonGreen),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _glass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.06 + 0.04 * _pulse.value)),
              boxShadow: [
                BoxShadow(
                    color: _neonPurple.withOpacity(0.04 * _pulse.value),
                    blurRadius: 30, spreadRadius: -5),
              ],
            ),
            child: child,
          ),
          child: Column(
            children: List.generate(cats.length, (i) {
              final score     = (cats[i].$2 as num).toDouble();
              final color     = cats[i].$3 as Color;
              final realColor = _scoreColor(score.toInt());
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cats[i].$1 as String,
                            style: const TextStyle(
                                color: _labelMid, fontSize: 12,
                                fontWeight: FontWeight.w500, letterSpacing: 0.1)),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Text('${score.toInt()}',
                              style: TextStyle(
                                color: realColor, fontSize: 13,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(
                                    color: realColor.withOpacity(0.6), blurRadius: 8)],
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (i < _barAnim.length)
                          AnimatedBuilder(
                            animation: Listenable.merge([_barAnim[i], _pulse]),
                            builder: (_, __) => FractionallySizedBox(
                              widthFactor: _barAnim[i].value * score / 100,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [color.withOpacity(0.7), color],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.4 + 0.25 * _pulse.value),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── BOTTOM ACTIONS ─────────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Column(children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  NotificationService.stopSpeaking();
                  setState(() {
                    _currentBubbleIndex = -1;
                    _muted = false;
                  });
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) _speakAll();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: _neonRed.withOpacity(0.12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        _neonRed.withOpacity(0.12),
                        _neonPurple.withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(
                        color: _neonRed.withOpacity(0.20 + 0.12 * _pulse.value)),
                    boxShadow: [
                      BoxShadow(
                          color: _neonRed.withOpacity(0.08 * _pulse.value),
                          blurRadius: 24, spreadRadius: -4),
                    ],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.replay_rounded, color: _neonRed.withOpacity(0.9), size: 15),
                    const SizedBox(width: 10),
                    Text('REJOUER LE RAPPORT',
                        style: TextStyle(
                          color: _labelHi, fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 1.5,
                          shadows: [Shadow(color: _neonRed.withOpacity(0.5), blurRadius: 10)],
                        )),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleMute,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.03),
                    border: Border.all(
                      color: (_muted ? _labelLo : _neonPurple)
                          .withOpacity(0.20 + 0.10 * _pulse.value),
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: _muted ? _labelMid : _neonPurple, size: 15,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _muted
                          ? 'MODE SILENCIEUX — appuyer pour entendre ma voix'
                          : 'JE TE PARLE — appuyer pour me faire taire',
                      style: TextStyle(
                        color: _muted ? _labelMid : _neonPurple,
                        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.8,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VOIX
  // ═══════════════════════════════════════════════════════════════════════════

  List<String> _buildSpeakQueue() {
    final List<String> queue = [];
    final r = _report!;

    final intro = r['intro']?.toString() ?? '';
    if (intro.isNotEmpty) queue.add(intro);

    final paths = (r['paths'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (paths.isNotEmpty) {
      queue.add("Voilà nos aventures d'aujourd'hui sur la route !");
      for (final p in paths) {
        final narration = p['narration']?.toString() ?? '';
        if (narration.isNotEmpty) queue.add(narration);
      }
    }

    final scoreComment = r['score_comment']?.toString() ?? '';
    if (scoreComment.isNotEmpty) {
      queue.add("Voilà comment s'est passée notre journée !");
      queue.add(scoreComment);
    }

    final alertsSummary = r['alerts_summary']?.toString() ?? '';
    final eventsCount   = (r['events_count'] ?? 0) as num;
    if (alertsSummary.isNotEmpty && eventsCount > 0) {
      queue.add("Côté alertes, voilà ce qui s'est passé sur la route…");
      queue.add(alertsSummary);
    }

    final events = (r['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (events.isNotEmpty) {
      queue.add("Laisse-moi te raconter les moments marquants de la journée.");
      for (final ev in events) {
        final voice = ev['car_voice']?.toString() ?? '';
        if (voice.isNotEmpty) queue.add(voice);
      }
    }

    final diagnostics = (r['diagnostics'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (diagnostics.isNotEmpty) {
      queue.add("Bon, j'ai aussi quelques petits soucis à te signaler…");
      for (final d in diagnostics) {
        final voice = d['car_voice']?.toString() ?? '';
        if (voice.isNotEmpty) queue.add(voice);
      }
    }

    final pattern = r['danger_pattern'] as Map<String, dynamic>?;
    final patternVoice = pattern?['car_voice']?.toString()
        ?? pattern?['message']?.toString() ?? '';
    if (patternVoice.isNotEmpty) {
      queue.add("Et je voulais te dire un truc important…");
      queue.add(patternVoice);
    }

    final docAlerts = (r['doc_alerts'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (docAlerts.isNotEmpty) {
      queue.add("Au fait, j'ai aussi des rappels administratifs pour toi.");
      for (final doc in docAlerts) {
        final voice = doc['car_voice']?.toString() ?? '';
        if (voice.isNotEmpty) queue.add(voice);
      }
    }

    final tip = r['tip']?.toString() ?? '';
    if (tip.isNotEmpty) {
      queue.add("Mon conseil du jour pour toi :");
      queue.add(tip);
    }

    final outro = r['outro']?.toString() ?? '';
    if (outro.isNotEmpty) queue.add(outro);

    return queue;
  }

  void _speakQueue(List<String> texts, int index) {
    if (_muted || !mounted || index >= texts.length) {
      if (mounted) setState(() => _currentBubbleIndex = -1);
      return;
    }

    if (index < _bubbleTexts.length) {
      setState(() => _currentBubbleIndex = index);
    } else {
      setState(() => _currentBubbleIndex = -1);
    }

    NotificationService.speak(texts[index]).then((_) {
      if (!mounted || _muted) return;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && !_muted) _speakQueue(texts, index + 1);
      });
    }).catchError((_) {
      if (mounted && !_muted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_muted) _speakQueue(texts, index + 1);
        });
      }
    });
  }

  void _speakAll() {
    if (_report == null || _muted) return;
    final queue = _buildSpeakQueue();
    if (queue.isEmpty) return;
    _speakQueue(queue, 0);
  }

  void _speakBubble(int index) {
    if (_muted || _report == null) return;
    final queue = _buildSpeakQueue();
    if (index >= queue.length) return;
    _speakQueue(queue, index);
  }

  Color _scoreColor(int s) {
    if (s >= 80) return _neonGreen;
    if (s >= 60) return _neonOrange;
    return _neonRed;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HELPER : Reverse geocoding via Nominatim
// ═══════════════════════════════════════════════════════════════════════════════

Future<String?> _reverseGeocode(double lat, double lng) async {
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lng&format=json&accept-language=fr',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'tahkidrive/1.0'},
    );
    if (response.statusCode == 200) {
      final data    = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final parts   = <String>[
        if (address['road']    != null) address['road']    as String,
        if (address['suburb']  != null) address['suburb']  as String
        else if (address['neighbourhood'] != null) address['neighbourhood'] as String,
        if (address['city']    != null) address['city']    as String
        else if (address['town']    != null) address['town']    as String
        else if (address['village'] != null) address['village'] as String,
      ];
      return parts.isNotEmpty ? parts.join(', ') : null;
    }
  } catch (e) {
    debugPrint('Geocoding error: $e');
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WIDGET : Carte flutter_map + timeline (tout-en-un)
// ═══════════════════════════════════════════════════════════════════════════════

class _PathMapCard extends StatefulWidget {
  final Map<String, dynamic> path;
  final Animation<double> pulse;
  const _PathMapCard({required this.path, required this.pulse});

  @override
  State<_PathMapCard> createState() => _PathMapCardState();
}

class _PathMapCardState extends State<_PathMapCard> {
  bool _expanded = false;
  late final MapController _mapController;

  // Adresses résolues
  String? _startAddress;
  String? _endAddress;
  bool    _addressLoading = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadAddresses();
  }

  /// Charge _startAddress et _endAddress depuis Nominatim,
  /// ou utilise les champs pré-résolus s'ils existent dans path.
  Future<void> _loadAddresses() async {
    // 1) Utilise les adresses déjà présentes dans le JSON si dispo
    final preStart = widget.path['start_address']?.toString();
    final preEnd   = widget.path['end_address']?.toString();

    if (preStart != null && preEnd != null) {
      if (mounted) setState(() {
        _startAddress   = preStart;
        _endAddress     = preEnd;
        _addressLoading = false;
      });
      return;
    }

    // 2) Sinon appel Nominatim
    final startLat = widget.path['start_lat'] as double?;
    final startLng = widget.path['start_lng'] as double?;
    final endLat   = widget.path['end_lat']   as double?;
    final endLng   = widget.path['end_lng']   as double?;

    final results = await Future.wait([
      if (startLat != null && startLng != null)
        _reverseGeocode(startLat, startLng)
      else
        Future.value(null),
      if (endLat != null && endLng != null)
        _reverseGeocode(endLat, endLng)
      else
        Future.value(null),
    ]);

    if (mounted) setState(() {
      _startAddress   = results[0];
      _endAddress     = results[1];
      _addressLoading = false;
    });
  }

  // ── Helpers géographiques ─────────────────────────────────────────────────

  LatLng _getCenter() {
    final sLat = widget.path['start_lat'] as double?;
    final sLng = widget.path['start_lng'] as double?;
    final eLat = widget.path['end_lat']   as double?;
    final eLng = widget.path['end_lng']   as double?;
    if (sLat != null && eLat != null) {
      return LatLng((sLat + eLat) / 2, (sLng! + eLng!) / 2);
    }
    if (sLat != null) return LatLng(sLat, sLng!);
    return const LatLng(36.8065, 10.1815);
  }

  double _getZoom() {
    final sLat = widget.path['start_lat'] as double?;
    final sLng = widget.path['start_lng'] as double?;
    final eLat = widget.path['end_lat']   as double?;
    final eLng = widget.path['end_lng']   as double?;
    if (sLat == null || eLat == null) return 13;
    final d = [(sLat - eLat).abs(), (sLng! - eLng!).abs()].reduce(max);
    if (d < 0.005) return 15;
    if (d < 0.02)  return 14;
    if (d < 0.05)  return 13;
    if (d < 0.1)   return 12;
    if (d < 0.5)   return 11;
    return 10;
  }

  List<LatLng> _buildPolylinePoints() {
    final pts = (widget.path['polyline'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (pts.isNotEmpty) {
      return pts.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();
    }
    final sLat = widget.path['start_lat'] as double?;
    final sLng = widget.path['start_lng'] as double?;
    final eLat = widget.path['end_lat']   as double?;
    final eLng = widget.path['end_lng']   as double?;
    if (sLat != null && eLat != null) {
      return [LatLng(sLat, sLng!), LatLng(eLat, eLng!)];
    }
    return [];
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final events  = (widget.path['events'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    final sLat = widget.path['start_lat'] as double?;
    final sLng = widget.path['start_lng'] as double?;
    if (sLat != null && sLng != null) {
      markers.add(Marker(
        point: LatLng(sLat, sLng),
        width: 32, height: 32,
        child: _MapPin(color: _neonGreen, icon: Icons.radio_button_checked_rounded),
      ));
    }

    final eLat = widget.path['end_lat'] as double?;
    final eLng = widget.path['end_lng'] as double?;
    if (eLat != null && eLng != null) {
      markers.add(Marker(
        point: LatLng(eLat, eLng),
        width: 32, height: 32,
        child: _MapPin(color: _neonRed, icon: Icons.flag_rounded),
      ));
    }

    for (final ev in events) {
      final lat = ev['lat'] as double?;
      final lng = ev['lng'] as double?;
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 28, height: 28,
        child: _MapPin(
          color: ev['is_critical'] == true
              ? _neonOrange
              : _neonOrange.withOpacity(0.7),
          icon: Icons.warning_rounded,
          size: 14,
        ),
      ));
    }
    return markers;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sLat   = widget.path['start_lat'] as double?;
    final sLng   = widget.path['start_lng'] as double?;
    final hasGps = sLat != null && sLng != null;
    final height = _expanded ? 320.0 : 200.0;
    final points = _buildPolylinePoints();

    // Fallbacks lisibles pour départ/arrivée
    final startLabel = _addressLoading
        ? 'Chargement…'
        : (_startAddress ?? widget.path['begin']?.toString() ?? '--:--');
    final endLabel = _addressLoading
        ? 'Chargement…'
        : (_endAddress ?? widget.path['end']?.toString() ?? '--:--');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ──────────────────────────────────────────────────────────────────
        //  CARTE
        // ──────────────────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: widget.pulse,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _neonPurple.withOpacity(0.20 + 0.10 * widget.pulse.value),
                ),
              ),
              child: Stack(children: [

                // Carte ou placeholder
                if (hasGps)
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _getCenter(),
                        initialZoom: _getZoom(),
                        interactionOptions: InteractionOptions(
                          flags: _expanded
                              ? InteractiveFlag.pinchZoom | InteractiveFlag.drag
                              : InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.9,  0,    0,    0, 240,
                            0,   -0.9,  0,    0, 240,
                            0,    0,   -0.9,  0, 240,
                            0,    0,    0,    1,   0,
                          ]),
                          child: TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.tahki_drive1',
                            additionalOptions: const {
                              'attribution': '© OpenStreetMap contributors',
                            },
                          ),
                        ),
                        if (points.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: points,
                                color: _neonRed,
                                strokeWidth: 3.0,
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: _buildMarkers()),
                      ],
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF0D0118),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.map_outlined, color: _labelLo, size: 32),
                          const SizedBox(height: 8),
                          const Text('GPS non disponible',
                              style: TextStyle(color: _labelMid, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),

                // Dégradé bas
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [_ink, _ink.withOpacity(0)],
                      ),
                    ),
                  ),
                ),

                // Stats overlay haut
                Positioned(
                  top: 12, left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Row(children: [
                          _StatChip(
                              icon: Icons.route_rounded,
                              value: widget.path['distance_str']?.toString() ?? '--',
                              color: _neonBlue),
                          const SizedBox(width: 10),
                          _StatChip(
                              icon: Icons.timer_rounded,
                              value: widget.path['duration_str']?.toString() ?? '--',
                              color: _neonPurple),
                          const SizedBox(width: 10),
                          _StatChip(
                              icon: Icons.speed_rounded,
                              value: '${(widget.path['max_speed'] as num?)?.toInt() ?? 0} km/h',
                              color: _neonRed),
                        ]),
                      ),
                    ),
                  ),
                ),

                // Bouton expand
                Positioned(
                  top: 12, right: 12,
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Icon(
                            _expanded
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            color: _labelHi, size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Départ / Arrivée bas (avec adresse) ───────────────────
                Positioned(
                  bottom: 10, left: 12, right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Départ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Départ',
                                style: const TextStyle(
                                    color: _labelMid, fontSize: 9, letterSpacing: 0.5)),
                            Text(
                              widget.path['begin']?.toString() ?? '--:--',
                              style: TextStyle(
                                color: _neonGreen, fontSize: 13, fontWeight: FontWeight.w700,
                                shadows: [Shadow(color: _neonGreen.withOpacity(0.6), blurRadius: 8)],
                              ),
                            ),
                            if (!_addressLoading && _startAddress != null)
                              Text(
                                _startAddress!,
                                style: const TextStyle(
                                  color: _labelMid, fontSize: 8, height: 1.3,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded,
                          color: _labelMid.withOpacity(0.4), size: 14),
                      // Arrivée
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Arrivée',
                                style: const TextStyle(
                                    color: _labelMid, fontSize: 9, letterSpacing: 0.5)),
                            Text(
                              widget.path['end']?.toString() ?? '--:--',
                              style: TextStyle(
                                color: _neonRed, fontSize: 13, fontWeight: FontWeight.w700,
                                shadows: [Shadow(color: _neonRed.withOpacity(0.6), blurRadius: 8)],
                              ),
                            ),
                            if (!_addressLoading && _endAddress != null)
                              Text(
                                _endAddress!,
                                style: const TextStyle(
                                  color: _labelMid, fontSize: 8, height: 1.3,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ──────────────────────────────────────────────────────────────────
        //  TIMELINE — avec adresses dans Départ et Arrivée
        // ──────────────────────────────────────────────────────────────────
        _PathTimeline(
          path: widget.path,
          pulse: widget.pulse,
          startAddress: _startAddress,
          endAddress: _endAddress,
          addressLoading: _addressLoading,
        ),
      ],
    );
  }
}

// ── Pin de marqueur ───────────────────────────────────────────────────────────
class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _MapPin({required this.color, required this.icon, this.size = 16});

  @override
  Widget build(BuildContext context) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      color: color, shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
    ),
    child: Icon(icon, color: Colors.white, size: size),
  );
}

// ── Mini stat chip ────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 10),
    const SizedBox(width: 4),
    Text(value, style: const TextStyle(
        color: _labelHi, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WIDGET : Timeline narrative avec adresses
// ═══════════════════════════════════════════════════════════════════════════════

class _PathTimeline extends StatelessWidget {
  final Map<String, dynamic> path;
  final Animation<double> pulse;
  final String? startAddress;
  final String? endAddress;
  final bool addressLoading;

  const _PathTimeline({
    required this.path,
    required this.pulse,
    this.startAddress,
    this.endAddress,
    this.addressLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final events = (path['events'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    // Sous-titre départ : adresse résolue ou distance à parcourir
    final startSubtitle = addressLoading
        ? 'Chargement de l\'adresse…'
        : (startAddress != null
        ? startAddress!
        : '${path['distance_str'] ?? ''} à parcourir');

    // Sous-titre arrivée : adresse résolue ou narration
    final endSubtitle = addressLoading
        ? 'Chargement de l\'adresse…'
        : (endAddress != null
        ? endAddress!
        : (path['narration']?.toString() ?? ''));

    final items = <_TimelineItem>[
      _TimelineItem(
        time: path['begin']?.toString() ?? '--:--',
        label: 'Départ',
        subtitle: startSubtitle,
        icon: Icons.flag_rounded,
        color: _neonGreen,
        isFirst: true,
      ),
      ...events.map((ev) => _TimelineItem(
        time: ev['heure']?.toString() ?? '--:--',
        label: ev['label']?.toString() ?? 'Alerte',
        subtitle: ev['is_critical'] == true ? '⚠️ Alerte critique' : 'Événement détecté',
        icon: ev['is_critical'] == true
            ? Icons.warning_rounded
            : Icons.notifications_rounded,
        color: ev['is_critical'] == true ? _neonRed : _neonOrange,
      )),
      _TimelineItem(
        time: path['end']?.toString() ?? '--:--',
        label: 'Arrivée',
        subtitle: endSubtitle,
        icon: Icons.sports_score_rounded,
        color: _neonPurple,
        isLast: true,
      ),
    ];

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.07 + 0.03 * pulse.value),
              ),
            ),
            child: Column(
              children: List.generate(items.length, (i) =>
                  _TimelineRow(item: items[i], isLast: i == items.length - 1, pulse: pulse)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineItem {
  final String time, label, subtitle;
  final IconData icon;
  final Color color;
  final bool isFirst, isLast;
  const _TimelineItem({
    required this.time, required this.label, required this.subtitle,
    required this.icon, required this.color,
    this.isFirst = false, this.isLast = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;
  final Animation<double> pulse;
  const _TimelineRow({required this.item, required this.isLast, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heure
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                item.time,
                style: TextStyle(
                  color: item.color, fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  shadows: [Shadow(color: item.color.withOpacity(0.5), blurRadius: 6)],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Dot + ligne
          Column(children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withOpacity(0.12),
                  border: Border.all(
                    color: item.color.withOpacity(
                        item.isFirst || item.isLast
                            ? 0.6 + 0.2 * pulse.value
                            : 0.4),
                    width: item.isFirst || item.isLast ? 1.5 : 1,
                  ),
                  boxShadow: [BoxShadow(
                    color: item.color.withOpacity(
                        item.isFirst || item.isLast
                            ? 0.18 + 0.08 * pulse.value
                            : 0.08),
                    blurRadius: 8,
                  )],
                ),
                child: Icon(item.icon, color: item.color, size: 13),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        item.color.withOpacity(0.3),
                        _labelLo.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),
          ]),

          const SizedBox(width: 12),

          // Contenu
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: isLast ? 8 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: TextStyle(
                        color: item.isFirst || item.isLast
                            ? _labelHi : _labelHi.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: item.isFirst || item.isLast
                            ? FontWeight.w600 : FontWeight.w500,
                      )),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.subtitle,
                        style: const TextStyle(
                          color: _labelMid, fontSize: 10, height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WIDGET : Card carrée diagnostic avec bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _DiagSquareCard extends StatefulWidget {
  final Map<String, dynamic> diag;
  final Animation<double> pulse;
  const _DiagSquareCard({required this.diag, required this.pulse});

  @override
  State<_DiagSquareCard> createState() => _DiagSquareCardState();
}

class _DiagSquareCardState extends State<_DiagSquareCard>
    with SingleTickerProviderStateMixin {

  bool _expanded = false;

  Color _parseColor(String? hex) {
    try { return Color(int.parse((hex ?? '#BF5AF2').replaceFirst('#', '0xFF'))); }
    catch (_) { return _neonPurple; }
  }

  @override
  Widget build(BuildContext context) {
    final diag      = widget.diag;
    final label     = diag['label']?.toString()     ?? 'Problème';
    final carVoice  = diag['car_voice']?.toString() ?? '';
    final urgency   = diag['urgency_hours'] as num? ?? 24;
    final count     = diag['count'] as num?         ?? 1;
    final severity  = diag['severity']?.toString()  ?? 'warning';
    final accent    = _parseColor(diag['color']?.toString());
    final isCritical = severity == 'critical';

    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _DiagDetailSheet(
            diag: diag, accent: accent,
            onClose: () {
              Navigator.pop(context);
              if (mounted) setState(() => _expanded = false);
            },
          ),
        ).then((_) { if (mounted) setState(() => _expanded = false); });
      });
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: AnimatedBuilder(
        animation: widget.pulse,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(0.12),
                    accent.withOpacity(0.04),
                    Colors.black.withOpacity(0.25),
                  ],
                  stops: const [0, 0.5, 1],
                ),
                border: Border.all(
                  color: accent.withOpacity(
                      isCritical
                          ? 0.40 + 0.18 * widget.pulse.value
                          : 0.20 + 0.08 * widget.pulse.value),
                  width: isCritical ? 1.2 : 0.8,
                ),
                boxShadow: [BoxShadow(
                  color: accent.withOpacity(
                      isCritical ? 0.18 * widget.pulse.value : 0.06),
                  blurRadius: 16, spreadRadius: -2,
                )],
              ),
              child: Stack(children: [
                if (isCritical)
                  Positioned(
                    top: -20, left: -20,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withOpacity(0.08 + 0.06 * widget.pulse.value),
                        boxShadow: [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 30)],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withOpacity(0.15),
                              border: Border.all(color: accent.withOpacity(0.35)),
                            ),
                            child: Icon(
                              isCritical ? Icons.error_rounded : Icons.build_rounded,
                              color: accent, size: 18,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (count > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accent.withOpacity(0.35)),
                                  ),
                                  child: Text('×${count.toInt()}',
                                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                              if (isCritical) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _neonRed.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text('CRITIQUE',
                                      style: TextStyle(color: _neonRed, fontSize: 7,
                                          fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(label,
                          style: const TextStyle(color: _labelHi, fontSize: 12,
                              fontWeight: FontWeight.w700, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (carVoice.isNotEmpty)
                        Text(carVoice,
                            style: const TextStyle(color: _labelMid, fontSize: 9,
                                height: 1.3, fontStyle: FontStyle.italic),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.access_time_rounded,
                                color: accent.withOpacity(0.6), size: 9),
                            const SizedBox(width: 3),
                            Text('${urgency.toInt()}h',
                                style: TextStyle(color: accent.withOpacity(0.8),
                                    fontSize: 9, fontWeight: FontWeight.w600)),
                          ]),
                          Row(children: [
                            Text('Détails',
                                style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 8),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET : Détail diagnostic
// ═══════════════════════════════════════════════════════════════════════════════

class _DiagDetailSheet extends StatelessWidget {
  final Map<String, dynamic> diag;
  final Color accent;
  final VoidCallback onClose;
  const _DiagDetailSheet({required this.diag, required this.accent, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final label    = diag['label']?.toString()           ?? 'Problème';
    final carVoice = diag['car_voice']?.toString()       ?? '';
    final diagnosis= diag['diagnosis']?.toString()       ?? '';
    final cause    = diag['cause']?.toString()           ?? '';
    final action   = diag['action_required']?.toString() ?? '';
    final risk     = diag['estimated_risk']?.toString()  ?? '';
    final urgency  = diag['urgency_hours'] as num?       ?? 24;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0118),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: accent.withOpacity(0.25), width: 0.8),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.15),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Icon(Icons.build_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(
                    color: _labelHi, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.access_time_rounded, color: accent.withOpacity(0.6), size: 11),
                  const SizedBox(width: 4),
                  Text('Action requise dans ${urgency.toInt()}h',
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
                child: const Icon(Icons.close_rounded, color: _labelMid, size: 14),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (carVoice.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withOpacity(0.07),
                    border: Border.all(color: accent.withOpacity(0.15)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🚗', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(carVoice,
                          style: const TextStyle(color: _labelHi, fontSize: 12,
                              height: 1.5, fontStyle: FontStyle.italic)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              _DetailSection(icon: Icons.search_rounded,              title: 'Diagnostic',         content: diagnosis, color: _neonBlue),
              const SizedBox(height: 12),
              _DetailSection(icon: Icons.help_outline_rounded,        title: 'Cause probable',     content: cause,     color: _neonOrange),
              const SizedBox(height: 12),
              _DetailSection(icon: Icons.check_circle_outline_rounded, title: 'Action requise',    content: action,    color: _neonGreen, highlight: true),
              const SizedBox(height: 12),
              _DetailSection(icon: Icons.warning_amber_rounded,       title: 'Risque si non traité', content: risk,  color: _neonRed),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title, content;
  final Color color;
  final bool highlight;
  const _DetailSection({
    required this.icon, required this.title,
    required this.content, required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: highlight ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
        border: Border.all(
          color: highlight ? color.withOpacity(0.25) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(color: _labelHi, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  final Animation<double> pulse;
  const _SectionLabel({required this.label, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => Row(children: [
          Container(
            width: 2, height: 14,
            decoration: BoxDecoration(
              color: _neonRed,
              borderRadius: BorderRadius.circular(1),
              boxShadow: [BoxShadow(
                  color: _neonRed.withOpacity(0.7 + 0.3 * pulse.value), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(
            color: _labelMid, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 2.5,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CARD DATA
// ═══════════════════════════════════════════════════════════════════════════════
class _CardData {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  const _CardData({
    required this.icon, required this.label,
    required this.value, required this.unit, required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PREMIUM CAROUSEL CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumCard extends StatelessWidget {
  final _CardData data;
  final Animation<double> pulse, shimmer;
  final bool active;
  const _PremiumCard({
    required this.data, required this.pulse,
    required this.shimmer, required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (_, __) {
        final glow = data.color.withOpacity(active ? (0.14 + 0.08 * pulse.value) : 0.04);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(active ? 0.09 : 0.04),
                        data.color.withOpacity(0.04),
                        Colors.black.withOpacity(0.2),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                    border: Border.all(
                      color: active
                          ? Colors.white.withOpacity(0.12 + 0.06 * pulse.value)
                          : Colors.white.withOpacity(0.05),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(color: glow, blurRadius: 28, spreadRadius: 0),
                      if (active)
                        BoxShadow(
                          color: data.color.withOpacity(0.07 * pulse.value),
                          blurRadius: 50, spreadRadius: -5,
                        ),
                    ],
                  ),
                ),
                if (active)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AnimatedBuilder(
                        animation: shimmer,
                        builder: (_, __) {
                          final dx = (shimmer.value * 2.5) - 0.7;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(dx - 0.5, -1),
                                end: Alignment(dx + 0.5, 1),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.04),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(data.icon, color: data.color.withOpacity(0.85), size: 18),
                          if (active)
                            Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: data.color,
                                boxShadow: [BoxShadow(
                                    color: data.color.withOpacity(0.9), blurRadius: 6)],
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(data.value,
                                    style: TextStyle(
                                      color: data.color, fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.5, height: 1,
                                      shadows: [Shadow(
                                          color: data.color.withOpacity(0.65), blurRadius: 20)],
                                    )),
                              ),
                              if (data.unit.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(data.unit,
                                      style: TextStyle(
                                          color: data.color.withOpacity(0.55),
                                          fontSize: 11, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(data.label,
                              style: const TextStyle(
                                  color: _labelMid, fontSize: 9,
                                  letterSpacing: 2.2, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  INSIGHT BUBBLE
// ═══════════════════════════════════════════════════════════════════════════════
class _InsightBubble extends StatelessWidget {
  final String text;
  final Animation<double> pulse;
  final bool compact, isActive;
  final String tag;

  const _InsightBubble({
    required this.text, required this.pulse,
    this.compact = false, this.tag = '', this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = text.contains('parfait') || text.contains('excellent') ||
        text.contains('🎉') || text.contains('hausse') || tag == 'outro';
    final isWarn = text.contains('alerte') || text.contains('Alerte') ||
        text.contains('attention') || text.contains('danger') || tag == 'alert';
    final accent = isGood ? _neonGreen : isWarn ? _neonRed : _neonPurple;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(isActive ? 0.11 : 0.07),
                  accent.withOpacity(isActive ? 0.07 : 0.03),
                ],
              ),
              border: Border.all(
                color: isActive
                    ? accent.withOpacity(0.4 + 0.2 * pulse.value)
                    : Colors.white.withOpacity(0.07 + 0.04 * pulse.value),
                width: isActive ? 1.2 : 0.8,
              ),
              boxShadow: [BoxShadow(
                color: accent.withOpacity(isActive ? 0.16 : 0.05 + 0.03 * pulse.value),
                blurRadius: isActive ? 24 : 16,
                spreadRadius: isActive ? -2 : 0,
              )],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2, height: compact ? 28 : 40,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: isActive ? accent : accent.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [BoxShadow(
                        color: accent.withOpacity(isActive ? 0.9 : 0.6),
                        blurRadius: isActive ? 12 : 6)],
                  ),
                ),
                Expanded(
                  child: Text(text,
                      style: TextStyle(
                        color: _labelHi.withOpacity(isActive ? 1.0 : 0.88),
                        fontSize: compact ? 11 : 13, height: 1.5, letterSpacing: 0.1,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: accent,
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.8), blurRadius: 8)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GLASS BUTTON
// ═══════════════════════════════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Animation<double> pulse;
  final Widget child;
  final Color? accentColor;
  const _GlassButton({
    required this.onTap, required this.pulse,
    required this.child, this.accentColor,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: (accentColor ?? Colors.white)
                      .withOpacity(0.10 + 0.06 * pulse.value),
                ),
                boxShadow: accentColor != null ? [
                  BoxShadow(
                      color: accentColor!.withOpacity(0.12 * pulse.value),
                      blurRadius: 14),
                ] : null,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AMBIENT ORBS
// ═══════════════════════════════════════════════════════════════════════════════
class _AmbientOrbs extends StatelessWidget {
  final Animation<double> pulse;
  const _AmbientOrbs({required this.pulse});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (_, __) => CustomPaint(painter: _OrbsPainter(pulse.value)),
  );
}

class _OrbsPainter extends CustomPainter {
  final double pulse;
  const _OrbsPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.12), 80 + 15 * pulse,
      Paint()
        ..color = _neonRed.withOpacity(0.035 + 0.02 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08), 100 + 20 * pulse,
      Paint()
        ..color = _neonPurple.withOpacity(0.04 + 0.02 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.75), 60 + 10 * pulse,
      Paint()
        ..color = _neonBlue.withOpacity(0.03 + 0.015 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
  }

  @override
  bool shouldRepaint(_OrbsPainter o) => o.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PREMIUM RING PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumRingPainter extends CustomPainter {
  final double progress, pulseValue, shimmer;
  final Color colorA, colorB;
  const _PremiumRingPainter({
    required this.progress, required this.pulseValue,
    required this.shimmer, required this.colorA, required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = size.shortestSide / 2 - 7;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(rect, 0, 2 * pi, false,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    if (progress <= 0) return;
    final sweep = 2 * pi * progress;
    canvas.drawArc(rect, -pi / 2, sweep, false,
      Paint()
        ..color = colorA.withOpacity(0.5 + 0.2 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 3 * pulseValue),
    );
    canvas.drawArc(rect, -pi / 2, sweep, false,
      Paint()
        ..color = colorA
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    final angle = -pi / 2 + sweep * shimmer;
    canvas.drawCircle(
      Offset(cx + r * cos(angle), cy + r * sin(angle)), 2.5,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_PremiumRingPainter o) =>
      o.progress != progress || o.pulseValue != pulseValue || o.shimmer != shimmer;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BUBBLE TAIL PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter o) => false;
}
