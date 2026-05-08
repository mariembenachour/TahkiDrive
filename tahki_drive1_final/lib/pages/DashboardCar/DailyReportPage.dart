import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:video_player/video_player.dart';
import '../../services/notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  PALETTE  — Premium Dark × Neon Accents
//  Inspiration: Apple Dark Mode + subtle neon signatures
// ═══════════════════════════════════════════════════════════════════════════════
const _ink        = Color(0xFF04000A);   // fond absolu, quasi-noir violacé
const _surface    = Color(0xFF0D0118);   // surface élevée
const _glass      = Color(0x0DFFFFFF);   // verre ultra-fin
const _glassHi    = Color(0x18FFFFFF);   // verre highlight

const _neonRed    = Color(0xFFFF2D55);   // rouge Apple-ish
const _neonPurple = Color(0xFFBF5AF2);   // violet Apple purple
const _neonBlue   = Color(0xFF0A84FF);   // bleu Apple accent
const _neonGreen  = Color(0xFF30D158);   // vert Apple

const _redGlow    = Color(0x44FF2D55);
const _purpGlow   = Color(0x33BF5AF2);

const _labelHi    = Color(0xFFF2F2F7);   // texte primaire Apple
const _labelMid   = Color(0xFF8E8E93);   // texte secondaire
const _labelLo    = Color(0xFF3A3A3C);   // texte tertiaire

// ═══════════════════════════════════════════════════════════════════════════════
class DailyReportPage extends StatefulWidget {
  final String cin;
  final String? date; // ← AJOUTÉ
  const DailyReportPage({super.key, required this.cin, this.date});
  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage>
    with TickerProviderStateMixin {

  Map<String, dynamic>? _report;
  bool _loading = true;

  // ── Video ──────────────────────────────────────────────────────────────────
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;
  bool _muted = true;

  // ── Master pulse (néons qui respirent lentement) ──────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // ── Entry (spring) ────────────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  // ── Score ring ────────────────────────────────────────────────────────────
  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;

  // ── Float doux ────────────────────────────────────────────────────────────
  late AnimationController _floatCtrl;
  late Animation<double>   _float;

  // ── Shimmer continu (cards) ───────────────────────────────────────────────
  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmer;

  // ── Carousel ──────────────────────────────────────────────────────────────
  final PageController _carouselCtrl = PageController(viewportFraction: 0.80);
  int _carouselPage = 0;

  // ── Bars ──────────────────────────────────────────────────────────────────
  final List<AnimationController> _barCtrl = [];
  final List<Animation<double>>   _barAnim = [];

  // ── Bubbles ───────────────────────────────────────────────────────────────
  final List<AnimationController> _bubbleCtrl  = [];
  final List<Animation<double>>   _bubbleFade  = [];
  final List<Animation<Offset>>   _bubbleSlide = [];
  final List<String>              _bubbleTexts = [];

  // ── Card stagger ─────────────────────────────────────────────────────────
  final List<AnimationController> _cardCtrl = [];
  final List<Animation<double>>   _cardAnim = [];

  @override
  void initState() {
    super.initState();
    _initVideo();
    _setupAnimations();
    _loadReport();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  VIDEO — FIX: utiliser asset() correctement avec pubspec.yaml
  // ─────────────────────────────────────────────────────────────────────────
  void _initVideo() {
    // IMPORTANT: Le chemin doit correspondre EXACTEMENT à ce qui est déclaré
    // dans pubspec.yaml sous flutter > assets:
    //   - assets/video/animation2.mp4
    // Et le chemin dans le code doit être 'assets/video/animation2.mp4'
    _videoCtrl = VideoPlayerController.asset('video/animation2.mp4')
      ..initialize().then((_) {
        _videoCtrl
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        if (mounted) setState(() => _videoReady = true);
      }).catchError((Object e) {
        debugPrint('❌ Video init error: $e');
        // La vidéo ne charge pas → fond gradient utilisé à la place
      });

    _videoCtrl.addListener(() {
      if (_videoCtrl.value.hasError) {
        debugPrint('❌ Video playback error: ${_videoCtrl.value.errorDescription}');
      }
    });
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _videoCtrl.setVolume(_muted ? 0 : 1);
    NotificationService.stopSpeaking();
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _setupAnimations() {
    // Pulse très lent et doux — style Apple breathing
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    // Entry : opacité + légère montée
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.7, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.8, curve: Curves.easeOutCubic)));
    _entryCtrl.forward();

    // Ring score
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutQuart);

    // Float très doux
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4500))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -4, end: 4)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Shimmer
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _buildBubbles(Map<String, dynamic> r) {
    _bubbleTexts
      ..clear()
      ..addAll([
        r['intro']          ?? '',
        r['alerts_summary'] ?? '',
        r['score_comment']  ?? '',
        r['tip']            ?? '',
        r['outro']          ?? '',
      ].whereType<String>().where((s) => s.isNotEmpty).toList());

    for (var c in _bubbleCtrl) c.dispose();
    _bubbleCtrl.clear(); _bubbleFade.clear(); _bubbleSlide.clear();

    for (int i = 0; i < _bubbleTexts.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 700));
      _bubbleCtrl.add(ctrl);
      _bubbleFade.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _bubbleSlide.add(Tween<Offset>(
          begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      Future.delayed(Duration(milliseconds: 300 + i * 600), () {
        if (mounted) ctrl.forward();
        if (mounted && i == 0) NotificationService.speak(_bubbleTexts[0]);
      });
    }

    for (var c in _barCtrl) c.dispose();
    _barCtrl.clear(); _barAnim.clear();
    for (int i = 0; i < 5; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200));
      _barCtrl.add(ctrl);
      _barAnim.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutQuart));
      Future.delayed(Duration(milliseconds: 700 + i * 120), () {
        if (mounted) ctrl.forward();
      });
    }

    for (var c in _cardCtrl) c.dispose();
    _cardCtrl.clear(); _cardAnim.clear();
    for (int i = 0; i < 5; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));
      _cardCtrl.add(ctrl);
      _cardAnim.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack));
      Future.delayed(Duration(milliseconds: 600 + i * 130), () {
        if (mounted) ctrl.forward();
      });
    }

    _ringCtrl.forward();
  }

  Future<void> _loadReport() async {
    final report = await NotificationService.getDailyReport(
        widget.cin,
        date: widget.date, // ← passe la date si fournie
    );
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
    for (var c in _bubbleCtrl) c.dispose();
    for (var c in _barCtrl)    c.dispose();
    for (var c in _cardCtrl)   c.dispose();
    NotificationService.stopSpeaking();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD ROOT
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final vidH  = size.height * 0.40;

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(children: [

        // ── FOND ABSOLU ───────────────────────────────────────────────────
// ── FOND ABSOLU — remplace ColoredBox par un gradient chaud ──────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0012),   // violet très sombre en haut (match vidéo)
                  Color(0xFF04000A),   // _ink en bas
                ],
                stops: [0.0, 0.55],
              ),
            ),
          ),
        ),
        // ── AMBIENT GLOW (orbes en arrière-plan) ─────────────────────────
        Positioned.fill(child: _AmbientOrbs(pulse: _pulse)),

        // ── VIDEO / HERO ZONE ─────────────────────────────────────────────
        Positioned(top: 0, left: 0, right: 0, height: vidH,
            child: _buildVideoZone(vidH)),

        // ── DÉGRADÉ BAS DE VIDEO ──────────────────────────────────────────
        // ── DÉGRADÉ BAS DE VIDEO — transition invisible ───────────────────────────────
        // Dégradé bas — commence PLUS TÔT et plus agressif
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  _ink.withOpacity(0.15),
                  _ink.withOpacity(0.70),
                  _ink,
                  _ink,
                ],
                stops: const [0.0, 0.40, 0.58, 0.78, 0.92, 1.0],
              ),
            ),
          ),
        ),
        // ── CONTENU SCROLLABLE ────────────────────────────────────────────
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

  Widget _buildVideoZone(double h) {
    return ClipRect(
      child: Stack(children: [
        if (_videoReady)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:  _videoCtrl.value.size.width,
                height: _videoCtrl.value.size.height,
                child:  VideoPlayer(_videoCtrl),
              ),
            ),
          )
        else
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A0030),
                      Color.lerp(const Color(0xFF2D0050),
                          const Color(0xFF3D0015), _pulse.value)!,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Dégradé bas — commence plus tard, reste léger
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                Colors.transparent,
                Colors.transparent,
                _ink.withOpacity(0.15),
                _ink.withOpacity(0.70),
                _ink,
                _ink,
                ],
                stops: const [0.0, 0.40, 0.58, 0.78, 0.92, 1.0],
              ),
            ),
          ),
        ),

        // Vignette latérale — très légère
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center, radius: 1.4,  // plus large = moins dark
                colors: [Colors.transparent, _ink.withOpacity(0.20)],  // était 0.4
              ),
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
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _labelHi, size: 14),
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
                      color: _labelHi,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: _neonRed.withOpacity(0.35 + 0.25 * _pulse.value),
                          blurRadius: 20,
                        ),
                      ],
                    )),
                Text('DU JOUR',
                    style: TextStyle(
                      color: _neonPurple.withOpacity(0.7 + 0.3 * _pulse.value),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.5,
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

  // ── LOADER ─────────────────────────────────────────────────────────────────
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Espace vidéo
        SizedBox(height: vidH * 0.65),

        // ── SCORE HERO ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildHeroSection(),
        ),
        const SizedBox(height: 28),

        // ── DIVIDER LABEL ────────────────────────────────────────────────
        _SectionLabel(label: 'MÉTRIQUES', pulse: _pulse),
        const SizedBox(height: 14),

        // ── CAROUSEL ─────────────────────────────────────────────────────
        _buildCarousel(),
        const SizedBox(height: 28),

        // ── ANALYSE IA ────────────────────────────────────────────────
        if (_bubbleTexts.isNotEmpty) ...[
          _SectionLabel(label: 'ANALYSE IA', pulse: _pulse),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildInsightsColumn(),
          ),
          const SizedBox(height: 28),
        ],

// ── DÉTAIL PAR CATÉGORIE ────────────────────────────────────────
        _SectionLabel(label: 'DÉTAIL PAR CATÉGORIE', pulse: _pulse),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildCategoryBars(),
        ),
        const SizedBox(height: 28),
        // ── REPLAY ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildReplayButton(),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildHeroSection() {
    final score = (_report!['score_today'] ?? 0) as num;
    final label = score >= 80 ? 'Excellent' : score >= 60 ? 'Correct' : 'À améliorer';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        // Score ring + label dessous
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
                    shimmer: _shimmer.value,
                    pulseValue: _pulse.value,
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_neonPurple, _neonPurple],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: Text('${score.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              height: 1,
                            )),
                      ),
                      Text('/100',
                          style: TextStyle(
                              color: _labelMid, fontSize: 8, letterSpacing: 1)),
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
                    colors: [
                      _neonRed.withOpacity(0.18),
                      _neonPurple.withOpacity(0.18),
                    ],
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
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 20),

        // Bulles verticales à droite
        Expanded(
          child: AnimatedBuilder(
            animation: _float,
            builder: (_, child) =>
                Transform.translate(offset: Offset(0, _float.value * 0.5), child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                _bubbleTexts.length.clamp(0, 2),
                    (i) {
                  if (i >= _bubbleFade.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FadeTransition(
                      opacity: _bubbleFade[i],
                      child: SlideTransition(
                        position: _bubbleSlide[i],
                        child: _InsightBubble(
                          text: _bubbleTexts[i],
                          pulse: _pulse,
                          compact: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── INSIGHTS COLUMN (tous les messages) ────────────────────────────────────
  Widget _buildInsightsColumn() {
    return Column(
      children: List.generate(_bubbleTexts.length, (i) {
        if (i >= _bubbleFade.length) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadeTransition(
            opacity: _bubbleFade[i],
            child: SlideTransition(
              position: _bubbleSlide[i],
              child: _InsightBubble(text: _bubbleTexts[i], pulse: _pulse),
            ),
          ),
        );
      }),
    );
  }

  // ── CAROUSEL ───────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    final score  = (_report!['score_today']    ?? 0) as num;
    final events = (_report!['events_count']   ?? 0) as num;
    final yest   = _report!['score_yesterday'] as num?;
    final diff   = yest != null ? score - yest : null;

    final cards = <_CardData>[
      _CardData(icon: Icons.speed_rounded,     label: 'VITESSE',
          value: '${_report!['score_vitesse']  ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_vitesse']  ?? 100) as int)),
      _CardData(icon: Icons.warning_amber_rounded, label: 'ALERTES',
          value: '${events.toInt()}',          unit: events == 0 ? '✦' : 'evt',
          color: events == 0 ? _neonGreen : _neonRed),
      _CardData(icon: Icons.trending_up_rounded, label: 'VS HIER',
          value: diff != null ? '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}' : '--',
          unit: diff == null ? '' : diff >= 0 ? '▲' : '▼',
          color: diff == null ? _labelMid : diff >= 0 ? _neonGreen : _neonRed),
      _CardData(icon: Icons.local_fire_department_rounded, label: 'FREINAGE',
          value: '${_report!['score_freinage'] ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_freinage'] ?? 100) as int)),
      _CardData(icon: Icons.remove_red_eye_rounded, label: 'VIGILANCE',
          value: '${_report!['score_vigilance'] ?? 100}', unit: 'pts',
          color: _scoreColor((_report!['score_vigilance'] ?? 100) as int)),
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
                    data: d, pulse: _pulse,
                    shimmer: _shimmer,
                    active: i == _carouselPage,
                  ),
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 12),
      // Dots pill-style
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(cards.length, (i) {
          final active = i == _carouselPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 5,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active
                  ? _neonRed
                  : _labelLo,
              boxShadow: active
                  ? [BoxShadow(color: _neonRed.withOpacity(0.7), blurRadius: 8)]
                  : null,
            ),
          );
        }),
      ),
    ]);
  }

  // ── CATEGORY BARS ──────────────────────────────────────────────────────────
  Widget _buildCategoryBars() {
    final cats = [
      ('Vitesse',   _report!['score_vitesse']   ?? 100, _neonBlue),
      ('Freinage',  _report!['score_freinage']  ?? 100, _neonPurple),
      ('Vigilance', _report!['score_vigilance'] ?? 100, _neonRed),
      ('Fatigue',   _report!['score_fatigue']   ?? 100, const Color(0xFFFF9F0A)),
      ('Sécurité',  _report!['score_securite']  ?? 100, _neonGreen),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
              final score = (cats[i].$2 as num).toDouble();
              final color = cats[i].$3;
              final realColor = _scoreColor(score.toInt());
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cats[i].$1,
                            style: const TextStyle(
                                color: _labelMid, fontSize: 12,
                                fontWeight: FontWeight.w500, letterSpacing: 0.1)),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Text('${score.toInt()}',
                              style: TextStyle(
                                color: realColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                      color: realColor.withOpacity(0.6),
                                      blurRadius: 8)
                                ],
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
                                      color: color.withOpacity(
                                          0.4 + 0.25 * _pulse.value),
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

  // ── REPLAY ─────────────────────────────────────────────────────────────────
  Widget _buildReplayButton() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _speakAll,
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
                    color: _neonRed.withOpacity(0.20 + 0.12 * _pulse.value),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: _neonRed.withOpacity(0.08 * _pulse.value),
                        blurRadius: 24, spreadRadius: -4),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded,
                        color: _neonRed.withOpacity(0.9),
                        size: 15),
                    const SizedBox(width: 10),
                    Text('REJOUER LE RAPPORT',
                        style: TextStyle(
                          color: _labelHi, fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                                color: _neonRed.withOpacity(0.5),
                                blurRadius: 10),
                          ],
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _speakAll() {
    if (_report == null) return;
    final t = [
      _report!['intro'], _report!['alerts_summary'],
      _report!['score_comment'], _report!['tip'], _report!['outro']
    ].whereType<String>().join('. ');
    NotificationService.speak(t);
  }

  Color _scoreColor(int s) {
    if (s >= 80) return _neonGreen;
    if (s >= 60) return const Color(0xFFFF9F0A);
    return _neonRed;
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
                  color: _neonRed.withOpacity(0.7 + 0.3 * pulse.value),
                  blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                color: _labelMid,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
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
  final Animation<double> pulse;
  final Animation<double> shimmer;
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
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Stack(children: [
                // Base
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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

                // Shimmer highlight (style Apple)
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

                // Content
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
                                boxShadow: [
                                  BoxShadow(color: data.color.withOpacity(0.9),
                                      blurRadius: 6)
                                ],
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
                              Text(data.value,
                                  style: TextStyle(
                                    color: data.color,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                    height: 1,
                                    shadows: [
                                      Shadow(color: data.color.withOpacity(0.0), blurRadius: 0),
                                      Shadow(color: data.color.withOpacity(0.65), blurRadius: 20),
                                    ],
                                  )),
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
  final bool compact;
  const _InsightBubble({
    required this.text, required this.pulse, this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = text.contains('parfait') || text.contains('excellent') ||
        text.contains('🎉') || text.contains('hausse');
    final isWarn = text.contains('alerte') || text.contains('Alerte') ||
        text.contains('attention') || text.contains('danger');

    final accentColor = isGood ? _neonGreen : isWarn ? _neonRed : _neonPurple;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: 14, vertical: compact ? 9 : 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.07),
                  accentColor.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.07 + 0.04 * pulse.value)),
              boxShadow: [
                BoxShadow(
                    color: accentColor.withOpacity(0.05 + 0.03 * pulse.value),
                    blurRadius: 16),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2, height: compact ? 30 : 40,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [BoxShadow(
                        color: accentColor.withOpacity(0.6), blurRadius: 6)],
                  ),
                ),
                Expanded(
                  child: Text(text,
                      style: TextStyle(
                        color: _labelHi.withOpacity(0.88),
                        fontSize: compact ? 11 : 13,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GLASS BUTTON (AppBar)
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
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
//  AMBIENT ORBS (fond atmosphérique)
// ═══════════════════════════════════════════════════════════════════════════════
class _AmbientOrbs extends StatelessWidget {
  final Animation<double> pulse;
  const _AmbientOrbs({required this.pulse});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (_, __) => CustomPaint(
        painter: _OrbsPainter(pulse.value)),
  );
}

class _OrbsPainter extends CustomPainter {
  final double pulse;
  const _OrbsPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Orbe rouge haut-gauche
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.12),
      80 + 15 * pulse,
      Paint()
        ..color = _neonRed.withOpacity(0.035 + 0.02 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    // Orbe violet haut-droite
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      100 + 20 * pulse,
      Paint()
        ..color = _neonPurple.withOpacity(0.04 + 0.02 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
    // Orbe bleu bas-centre
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.75),
      60 + 10 * pulse,
      Paint()
        ..color = _neonBlue.withOpacity(0.03 + 0.015 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
  }

  @override
  bool shouldRepaint(_OrbsPainter o) => o.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PREMIUM RING PAINTER — dégradé + shimmer
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumRingPainter extends CustomPainter {
  final double progress, pulseValue, shimmer;
  final Color colorA, colorB;
  const _PremiumRingPainter({
    required this.progress, required this.pulseValue,
    required this.shimmer,  required this.colorA, required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = size.shortestSide / 2 - 7;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track background
    canvas.drawArc(rect, 0, 2 * pi, false,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final sweep = 2 * pi * progress;

    // Outer glow
    canvas.drawArc(rect, -pi / 2, sweep, false,
      Paint()
        ..color = colorA.withOpacity(0.5 + 0.2 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 3 * pulseValue),
    );

// Main arc propre
    canvas.drawArc(rect, -pi / 2, sweep, false,
      Paint()
        ..color = colorA
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Highlight blanc fin (shimmer)
    final shimmerAngle = -pi / 2 + sweep * shimmer;
    final hx = cx + r * cos(shimmerAngle);
    final hy = cy + r * sin(shimmerAngle);
    canvas.drawCircle(
      Offset(hx, hy), 2.5,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_PremiumRingPainter o) =>
      o.progress != progress || o.pulseValue != pulseValue || o.shimmer != shimmer;
}
