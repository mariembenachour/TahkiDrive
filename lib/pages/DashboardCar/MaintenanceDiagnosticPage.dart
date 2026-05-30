import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

// ══════════════════════════════════════════════════════════
// DONNÉES PAR TYPE D'ENTRETIEN
// ══════════════════════════════════════════════════════════

class _MaintenanceData {
  final String label;
  final IconData icon;
  final Color color;
  final String carVoice;
  final String whatHappens;
  final String causeProbable;
  final List<_Consequence> consequences;
  final String actionRequired;
  final String urgencyLabel;

  const _MaintenanceData({
    required this.label,
    required this.icon,
    required this.color,
    required this.carVoice,
    required this.whatHappens,
    required this.causeProbable,
    required this.consequences,
    required this.actionRequired,
    required this.urgencyLabel,
  });
}

class _Consequence {
  final String delay;
  final String msg;
  final String sev; // 'critical' | 'warning' | 'info'
  const _Consequence(this.delay, this.msg, this.sev);
}

const Map<String, _MaintenanceData> kMaintenanceInfo = {
  'Oil Change': _MaintenanceData(
    label: 'Vidange',
    icon: Icons.opacity_rounded,
    color: Color(0xFFFF8C00),
    carVoice:
    "Mon huile commence à vieillir ! Elle perd ses propriétés lubrifiantes et mon moteur souffre en silence... 🛢️",
    whatHappens:
    "L'huile moteur se dégrade avec le temps et les kilomètres. Elle s'oxyde, accumule des impuretés et perd sa viscosité optimale.",
    causeProbable:
    "Usure normale des additifs de l'huile. La chaleur et les cycles moteur dégradent progressivement la formule lubrifiante.",
    consequences: [
      _Consequence('Dans 1 000 km',  'Usure accélérée des pistons et bielles',         'warning'),
      _Consequence('Dans 3 000 km',  'Dépôts de carbone dans le moteur',               'warning'),
      _Consequence('Dans 5 000 km',  'Grippage moteur possible, réparation très coûteuse', 'critical'),
      _Consequence('Long terme',     'Réduction de durée de vie moteur de 30 à 50%',    'critical'),
    ],
    actionRequired: "Programmer une vidange dans les plus brefs délais. Prévoir filtre à huile + huile de remplacement.",
    urgencyLabel: 'RECOMMANDÉ MAINTENANT',
  ),

  'Tire': _MaintenanceData(
    label: 'Pneus',
    icon: Icons.tire_repair_rounded,
    color: Color(0xFF2979FF),
    carVoice:
    "Mes pneus commencent à s'user ! La bande de roulement s'amincit et ma tenue de route en prend un coup... 🛞",
    whatHappens:
    "La gomme des pneus s'use progressivement avec les kilomètres. La profondeur des rainures diminue, réduisant l'évacuation de l'eau et l'adhérence.",
    causeProbable:
    "Usure normale par friction avec la route. Peut être accélérée par un défaut de gonflage, un mauvais alignement ou des freinages brusques répétés.",
    consequences: [
      _Consequence('À partir de maintenant', 'Distance de freinage augmentée sur route mouillée', 'warning'),
      _Consequence('Dans 2 000 km',  'Risque d\'aquaplaning par temps de pluie',           'warning'),
      _Consequence('Dans 5 000 km',  'Éclatement de pneu possible à haute vitesse',         'critical'),
      _Consequence('En cas de pluie', 'Perte de contrôle — très dangereux',                 'critical'),
    ],
    actionRequired:
    "Vérifier la profondeur des rainures (minimum légal 1,6mm). Remplacer les pneus usés par paire.",
    urgencyLabel: 'SÉCURITÉ PRIORITAIRE',
  ),

  'Brake': _MaintenanceData(
    label: 'Freins',
    icon: Icons.sports_score_rounded,
    color: Color(0xFFFF4444),
    carVoice:
    "Mes plaquettes de frein s'amincissent ! Je freine encore bien, mais dans quelques km ça va changer... 🚨",
    whatHappens:
    "Les plaquettes de frein s'usent à chaque freinage. Sous le seuil critique, le métal frotte directement sur le disque, dégradant les deux.",
    causeProbable:
    "Friction normale lors des freinages. Usure plus rapide si freinages brusques fréquents, ou disques de frein voilés.",
    consequences: [
      _Consequence('Dans 1 000 km',  'Bruit de grincement au freinage',                   'info'),
      _Consequence('Dans 2 000 km',  'Dégradation des disques (très coûteux à remplacer)', 'warning'),
      _Consequence('Dans 3 000 km',  'Distance de freinage augmentée dangereusement',      'critical'),
      _Consequence('Au-delà',        'Perte de freinage — risque vital',                   'critical'),
    ],
    actionRequired:
    "Faire contrôler et remplacer les plaquettes. Vérifier l'état des disques en même temps.",
    urgencyLabel: 'SÉCURITÉ CRITIQUE',
  ),

  'Battery': _MaintenanceData(
    label: 'Batterie',
    icon: Icons.battery_charging_full_rounded,
    color: Color(0xFF00E676),
    carVoice:
    "Ma batterie vieillit et ses cellules faiblissent ! Par temps froid ou après un long arrêt, je pourrais te laisser en plan... 🔋",
    whatHappens:
    "Les cellules chimiques d'une batterie se dégradent avec le temps et les cycles charge/décharge. La capacité et la puissance de démarrage diminuent.",
    causeProbable:
    "Vieillissement naturel des plaques de plomb. Accéléré par les courts trajets (batterie jamais pleinement rechargée) ou températures extrêmes.",
    consequences: [
      _Consequence('Par temps froid',    'Démarrage difficile ou impossible',            'warning'),
      _Consequence('Après long arrêt',   'Batterie à plat — appel dépanneur nécessaire', 'warning'),
      _Consequence('En cas de défaillance', 'Panne électrique complète en roulant',      'critical'),
      _Consequence('Long terme',          'Dommages alternateur si batterie morte',      'critical'),
    ],
    actionRequired:
    "Faire tester la batterie (test de charge). La remplacer si elle ne tient plus la charge.",
    urgencyLabel: 'PRÉVENTION RECOMMANDÉE',
  ),

  'Distribution': _MaintenanceData(
    label: 'Distribution',
    icon: Icons.settings_rounded,
    color: Color(0xFFAA00FF),
    carVoice:
    "Ma courroie de distribution approche de sa limite ! Si elle casse, c'est le moteur entier qui lâche instantanément... ⚙️",
    whatHappens:
    "La courroie de distribution synchronise le vilebrequin et les arbres à cames. Elle se fragilise avec le temps et les kilomètres.",
    causeProbable:
    "Vieillissement du matériau (caoutchouc + fibres). Les conditions thermiques et mécaniques dégradent progressivement la courroie.",
    consequences: [
      _Consequence('Si elle casse',     'Piston percute les soupapes — moteur hors service', 'critical'),
      _Consequence('Réparation moteur', 'Coût entre 2 000 et 8 000 DT selon les dégâts',    'critical'),
      _Consequence('En roulant',        'Panne sèche instantanée, perte de direction/freinage', 'critical'),
      _Consequence('Préventif',         'Remplacement = 400-800 DT — incomparable vs moteur', 'info'),
    ],
    actionRequired:
    "Remplacer IMMÉDIATEMENT la courroie + kit distribution (tendeur, galet, pompe à eau). Ne pas attendre.",
    urgencyLabel: 'URGENT — RISQUE MOTEUR',
  ),

  'Embrayage': _MaintenanceData(
    label: 'Embrayage',
    icon: Icons.compare_arrows_rounded,
    color: Color(0xFFFF6D00),
    carVoice:
    "Mon embrayage fatigue ! Je glisse un peu quand tu accélères fort et les changements de vitesse se font moins bien... 🔧",
    whatHappens:
    "Le disque d'embrayage s'use par friction lors des changements de vitesse. À terme, il patine sous charge et ne transmet plus correctement la puissance.",
    causeProbable:
    "Usure normale par friction. Accélérée par les démarrages brutaux, les embrayages courts en circulation urbaine ou la conduite en montée.",
    consequences: [
      _Consequence('Dans 2 000 km',   'Patinage à l\'accélération — consommation en hausse', 'warning'),
      _Consequence('Dans 5 000 km',   'Impossibilité de passer certains rapports',           'warning'),
      _Consequence('Au-delà',         'Blocage complet — véhicule immobilisé',                'critical'),
      _Consequence('Volant moteur',   'Risque d\'endommager le volant moteur (+600 DT)',      'critical'),
    ],
    actionRequired:
    "Remplacer le kit embrayage complet (disque + mécanisme + butée). Intervenir avant blocage total.",
    urgencyLabel: 'INTERVENTION PROCHAINE',
  ),
};

// ══════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ══════════════════════════════════════════════════════════

class MaintenanceDiagnosticPage extends StatefulWidget {
  final String maintenanceType; // "Oil Change", "Tire", "Brake", etc.
  final int kmSinceRepair;
  final int kmInterval;
  final int kmRemaining;
  final String? dateNext; // estimation
  final int? daysLeft;

  const MaintenanceDiagnosticPage({
    required this.maintenanceType,
    required this.kmSinceRepair,
    required this.kmInterval,
    required this.kmRemaining,
    this.dateNext,
    this.daysLeft,
    super.key,
  });

  @override
  State<MaintenanceDiagnosticPage> createState() =>
      _MaintenanceDiagnosticPageState();
}

class _MaintenanceDiagnosticPageState
    extends State<MaintenanceDiagnosticPage> with TickerProviderStateMixin {
  // ── Couleurs ────────────────────────────────────────────
  static const _kBg       = Color(0xFF0D0B1E);
  static const _kBgMid    = Color(0xFF13102A);
  static const _kCard     = Color(0xFF1C1836);
  static const _kBorder   = Color(0xFF2D2750);
  static const _kPurple   = Color(0xFF7C4DFF);
  static const _kBlue     = Color(0xFF2979FF);

  // ── Animations ──────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _fabCtrl;

  late final Animation<double> _pulse;
  late final Animation<double> _slide;
  late final Animation<double> _progressAnim;
  late final Animation<double> _fabScale;

  // ── TTS ─────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  String? _playingKey;
  int _lastPartIndex = 0;










  // ── Getters ─────────────────────────────────────────────
  _MaintenanceData get _info =>
      kMaintenanceInfo[widget.maintenanceType] ??
          kMaintenanceInfo['Oil Change']!;

  double get _ratio =>
      (widget.kmSinceRepair / widget.kmInterval).clamp(0.0, 1.5);

  String get _urgencyLevel {
    if (_ratio >= 1.0) return 'DÉPASSÉ';
    if (_ratio >= 0.90) return 'CRITIQUE';
    if (_ratio >= 0.70) return 'URGENT';
    return 'PRÉVENTION';
  }

  Color get _urgencyColor {
    if (_ratio >= 1.0) return const Color(0xFFFF4444);
    if (_ratio >= 0.90) return const Color(0xFFFF4444);
    if (_ratio >= 0.70) return const Color(0xFFFF8C00);
    return const Color(0xFF2979FF);
  }

  // ── Init ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTts();
    // Auto-play après un délai
    Future.delayed(const Duration(milliseconds: 800), _autoPlay);
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _pulse = Tween<double>(begin: 0.93, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _slide = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
    _progressAnim = Tween<double>(begin: 0.0, end: _ratio.clamp(0.0, 1.0))
        .animate(CurvedAnimation(
        parent: _progressCtrl, curve: Curves.easeOutCubic));
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _progressCtrl.forward();
        _fabCtrl.forward();
      }
    });
  }



  void _autoPlay() {
    if (!mounted) return;
    _speakFull();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _particleCtrl.dispose();
    _rotateCtrl.dispose();
    _progressCtrl.dispose();
    _fabCtrl.dispose();
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    _tts.stop();
    super.dispose();
  }

// ── TTS helpers ─────────────────────────────────────────
  // ── TTS helpers — REMPLACER ENTIÈREMENT ─────────────────

  Completer<void>? _ttsCompleter;

  Future<void> _initTts() async {
    await _tts.setLanguage("fr-FR");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });
    _tts.setCancelHandler(() {
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });
    _tts.setErrorHandler((_) {
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });
  }

  List<String> _buildFullParts() {
    final info = _info;
    return [
      info.label,
      _urgencyLevel == 'DÉPASSÉ'
          ? 'Entretien dépassé de ${widget.kmRemaining.abs()} kilomètres !'
          : 'Il me reste ${widget.kmRemaining} kilomètres avant le prochain entretien.',
      info.carVoice,
      'Ce qui se passe : ${info.whatHappens}',
      'Cause probable : ${info.causeProbable}',
      'Action requise : ${info.actionRequired}',
    ];
  }

  Future<void> _speakFromIndex(int startIndex) async {
    // Stopper proprement
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final parts = _buildFullParts();
    final from  = startIndex.clamp(0, parts.length - 1);

    setState(() { _isPlaying = true; _playingKey = 'full'; });

    for (int i = from; i < parts.length; i++) {
      _lastPartIndex = i;
      final sentence = parts[i].trim();
      if (sentence.isEmpty) continue;

      _ttsCompleter = Completer<void>();
      await _tts.speak(sentence);
      await _ttsCompleter!.future;

      // Si _ttsCompleter == null → stopSpeaking() a été appelé → arrêt
      if (_ttsCompleter == null) break;
    }

    if (mounted) {
      // Fin naturelle → reset
      if (_ttsCompleter != null) _lastPartIndex = 0;
      setState(() { _isPlaying = false; _playingKey = null; });
    }
  }

  void _speakFull() => _speakFromIndex(0);

  void _toggleVoice() async {
    if (_isPlaying) {
      // STOP → sauvegarder _lastPartIndex (déjà à jour dans la boucle)
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
      _ttsCompleter = null; // signal d'arrêt pour la boucle
      await _tts.stop();
      if (mounted) setState(() { _isPlaying = false; _playingKey = null; });
    } else {
      // REPRENDRE depuis _lastPartIndex
      _speakFromIndex(_lastPartIndex);
    }
  }

  Future<void> _speakSection(String key, String text) async {
    if (_playingKey == key && _isPlaying) {
      // Stop ce paragraphe
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
      _ttsCompleter = null;
      await _tts.stop();
      if (mounted) setState(() { _isPlaying = false; _playingKey = null; });
      return;
    }
    // Stopper tout puis lire ce paragraphe
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() { _isPlaying = true; _playingKey = key; });
    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    await _ttsCompleter!.future;
    if (mounted && _playingKey == key) {
      setState(() { _isPlaying = false; _playingKey = null; });
    }
  }
  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: _buildFab(),
      body: Stack(children: [
        _buildBg(),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _slide,
                child: SlideTransition(
                  position: Tween<Offset>(
                      begin: const Offset(0, 0.06), end: Offset.zero)
                      .animate(_slide),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(children: [
                      const SizedBox(height: 20),
                      _buildCarVoiceCard(),
                      const SizedBox(height: 16),
                      _buildKmProgress(),
                      const SizedBox(height: 16),
                      _buildDiagCard(),
                      const SizedBox(height: 16),
                      _buildConsequences(),
                      const SizedBox(height: 16),
                      _buildActionCard(),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ── FAB ─────────────────────────────────────────────────
  Widget _buildFab() {
    return ScaleTransition(
      scale: _fabScale,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Transform.scale(
          scale: _isPlaying ? (0.96 + 0.04 * _pulse.value) : 1.0,
          child: GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _isPlaying
                      ? [_kPurple, const Color(0xFF4A00D4)]
                      : [const Color(0xFF251E4A), const Color(0xFF1A1535)],
                  center: Alignment.topLeft, radius: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPlaying
                        ? _kPurple.withOpacity(0.6)
                        : Colors.black.withOpacity(0.5),
                    blurRadius: _isPlaying ? 28 : 16,
                  ),
                ],
                border: Border.all(
                  color: _isPlaying
                      ? _kPurple.withOpacity(0.8)
                      : const Color(0xFF2D2750),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: _isPlaying ? Colors.white : _kPurple,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── APP BAR ─────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    final info = _info;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _kBgMid,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: ShaderMask(
        shaderCallback: (b) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB39DDB)])
            .createShader(b),
        child: const Text('Entretien Véhicule',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kBg,
                  _kBgMid,
                  info.color.withOpacity(0.2),
                ],
              ),
            ),
          ),
          // Orb déco
          Positioned(
            top: -40, right: -40,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      info.color.withOpacity(0.15),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),
          // Icône flottante
          Positioned(
            right: 20, top: 55,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 0.9 + 0.1 * _pulse.value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      info.color.withOpacity(0.25),
                      info.color.withOpacity(0.05),
                    ]),
                    border: Border.all(
                        color: info.color.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: info.color.withOpacity(0.3), blurRadius: 30)
                    ],
                  ),
                  child: Icon(info.icon, color: info.color, size: 38),
                ),
              ),
            ),
          ),
          // Texte
          Positioned(
            left: 20, bottom: 20, right: 110,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _urgencyColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _urgencyColor.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _PulsingDot(color: _urgencyColor),
                      const SizedBox(width: 6),
                      Text(_urgencyLevel,
                          style: TextStyle(
                              color: _urgencyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(info.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1)),
                  const SizedBox(height: 6),
                  Text(info.urgencyLabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                ]),
          ),
        ]),
      ),
    );
  }

  // ── CAR VOICE ───────────────────────────────────────────
  Widget _buildCarVoiceCard() {
    final info = _info;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                info.color.withOpacity(0.15),
                _kPurple.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: info.color.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                  color: info.color.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 1)
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar voiture
            Transform.scale(
              scale: _isPlaying ? (0.95 + 0.05 * _pulse.value) : 1.0,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: info.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: info.color.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: info.color.withOpacity(0.3), blurRadius: 12)
                  ],
                ),
                child: _isPlaying && _playingKey == 'full'
                    ? _WaveBars(color: info.color)
                    : Icon(Icons.directions_car_rounded,
                    color: info.color, size: 26),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _PulsingDot(color: info.color),
                      const SizedBox(width: 6),
                      Text('MA VOITURE PARLE',
                          style: TextStyle(
                              color: info.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4)),
                    ]),
                    const SizedBox(height: 8),
                    Text(info.carVoice,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.65,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _toggleVoice,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: info.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: info.color.withOpacity(0.35)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPlaying
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                                color: info.color, size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isPlaying ? 'Arrêter' : 'Réécouter tout',
                                style: TextStyle(
                                    color: info.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ]),
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── KM PROGRESS ─────────────────────────────────────────
  Widget _buildKmProgress() {
    final info     = _info;
    final isOver   = widget.kmRemaining <= 0;
    final barColor = isOver ? const Color(0xFFFF4444) : info.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: barColor.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Titre
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: barColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.speed_rounded, color: barColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text('KILOMÉTRAGE',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: barColor.withOpacity(0.35)),
              ),
              child: Text(
                isOver
                    ? '${widget.kmRemaining.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km dépassés'
                    : '${widget.kmRemaining.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km restants',
                style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          // Barre
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kBorder, width: 0.5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progressAnim.value,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOver
                                ? [const Color(0xFFFF4444), const Color(0xFFAA0000)]
                                : [_kBlue, barColor],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                                color: barColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text(
                      '0 km',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10),
                    ),
                    const Spacer(),
                    Text(
                      '${(widget.kmInterval / 1000).round()} 000 km',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10),
                    ),
                  ]),
                ]),
          ),
          const SizedBox(height: 20),
          // Stats 3 colonnes
          Row(children: [
            _KmStat(
              label: 'Parcourus',
              value: '${_fmtKm(widget.kmSinceRepair)} km',
              color: barColor,
            ),
            _KmDivider(),
            _KmStat(
              label: 'Intervalle',
              value: '${_fmtKm(widget.kmInterval)} km',
              color: Colors.white.withOpacity(0.5),
            ),
            _KmDivider(),
            _KmStat(
              label: widget.kmRemaining <= 0 ? 'Dépassé de' : 'Restants',
              value: '${_fmtKm(widget.kmRemaining.abs())} km',
              color: isOver ? const Color(0xFFFF4444) : const Color(0xFF00E676),
            ),
          ]),
          if (widget.dateNext != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    color: Colors.white.withOpacity(0.35), size: 14),
                const SizedBox(width: 8),
                Text(
                  'Date estimée : ${widget.dateNext}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '(estimation)',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  String _fmtKm(int km) => km
      .abs()
      .toString()
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  // ── DIAG CARD ───────────────────────────────────────────
  Widget _buildDiagCard() {
    final info = _info;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _DarkCard(
        title: 'ANALYSE',
        titleIcon: Icons.biotech_rounded,
        titleColor: _kPurple,
        child: Column(children: [
          _DiagRow(
            icon: Icons.local_fire_department_rounded,
            color: info.color,
            label: 'Ce qui se passe',
            value: info.whatHappens,
            isPlaying: _playingKey == 'whatHappens' && _isPlaying,
            onVoc: () => _speakSection('whatHappens', info.whatHappens),
          ),
          _Divider(),
          _DiagRow(
            icon: Icons.search_rounded,
            color: const Color(0xFFFF8C00),
            label: 'Cause probable',
            value: info.causeProbable,
            isPlaying: _playingKey == 'cause' && _isPlaying,
            onVoc: () => _speakSection('cause', info.causeProbable),
          ),
        ]),
      ),
    );
  }

  // ── CONSÉQUENCES ────────────────────────────────────────
  Widget _buildConsequences() {
    final info = _info;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _DarkCard(
        title: 'SI RIEN N\'EST FAIT',
        titleIcon: Icons.auto_graph_rounded,
        titleColor: _kBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voici ce qui risque de se passer si l\'entretien est repoussé :',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            ...info.consequences.asMap().entries.map(
                  (e) => _ConsequenceRow(
                delay: e.value.delay,
                msg: e.value.msg,
                sev: e.value.sev,
                index: e.key,
                isLast: e.key == info.consequences.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ACTION CARD ─────────────────────────────────────────
  Widget _buildActionCard() {
    final info = _info;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _urgencyColor.withOpacity(0.18),
                _urgencyColor.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _urgencyColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                  color: _urgencyColor.withOpacity(0.2), blurRadius: 20)
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _urgencyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: _urgencyColor.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.build_rounded,
                      color: _urgencyColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACTION REQUISE',
                            style: TextStyle(
                                color: _urgencyColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 8),
                        Text(info.actionRequired,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () =>
                              _speakSection('action', info.actionRequired),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _urgencyColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _urgencyColor.withOpacity(0.35)),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _playingKey == 'action' && _isPlaying
                                        ? Icons.stop_rounded
                                        : Icons.volume_up_rounded,
                                    color: _urgencyColor, size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _playingKey == 'action' && _isPlaying
                                        ? 'Arrêter'
                                        : 'Écouter',
                                    style: TextStyle(
                                        color: _urgencyColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                          ),
                        ),
                      ]),
                ),
              ]),
        ),
      ),
    );
  }

  // ── BACKGROUND ──────────────────────────────────────────
  Widget _buildBg() {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (_, __) => CustomPaint(
        painter:
        _BgPainter(_particleCtrl.value, _rotateCtrl.value, _info.color),
        child: Container(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _KmStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KmStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _KmDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 36,
      color: const Color(0xFF2D2750),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ConsequenceRow extends StatelessWidget {
  final String delay, msg, sev;
  final int index;
  final bool isLast;
  const _ConsequenceRow({
    required this.delay,
    required this.msg,
    required this.sev,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = sev == 'critical'
        ? const Color(0xFFFF4444)
        : sev == 'warning'
        ? const Color(0xFFFF8C00)
        : const Color(0xFF2979FF);
    final Color bg = sev == 'critical'
        ? const Color(0xFF2A0A0A)
        : sev == 'warning'
        ? const Color(0xFF1F1200)
        : const Color(0xFF0A1530);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          if (!isLast)
            Container(width: 2, height: 52, color: c.withOpacity(0.2)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(msg,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        height: 1.5)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withOpacity(0.4)),
                ),
                child: Text(delay,
                    style: TextStyle(
                        color: c, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  final bool isPlaying;
  final VoidCallback onVoc;

  const _DiagRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isPlaying,
    required this.onVoc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: onVoc,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying
                      ? color.withOpacity(0.25)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isPlaying
                        ? color.withOpacity(0.7)
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: isPlaying ? color : Colors.white.withOpacity(0.4),
                  size: 14,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.6)),
        ]),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: const Color(0xFF2D2750)),
  );
}

class _DarkCard extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final Color titleColor;
  final Widget child;

  const _DarkCard({
    required this.title,
    required this.titleIcon,
    required this.titleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1836),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2D2750)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: titleColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: titleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: titleColor.withOpacity(0.3)),
              ),
              child: Icon(titleIcon, color: titleColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
          ]),
        ),
        Divider(height: 1, color: const Color(0xFF2D2750)),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.2, end: 1.0).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(
      width: 6, height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.7), blurRadius: 6)
        ],
      ),
    ),
  );
}

class _WaveBars extends StatefulWidget {
  final Color color;
  const _WaveBars({required this.color});

  @override
  State<_WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<_WaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const heights = [4.0, 12.0, 18.0, 8.0, 14.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: heights.asMap().entries.map((e) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = (e.key * 0.25 + _c.value) % 1.0;
          return Container(
            width: 3,
            height: 3.0 + e.value * (0.3 + 0.7 * v),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  widget.color.withOpacity(0.4),
                  widget.color,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      )).toList(),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double progress, rotate;
  final Color accent;
  _BgPainter(this.progress, this.rotate, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D0B1E), Color(0xFF13102A), Color(0xFF0F0E25)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final paint = Paint()..style = PaintingStyle.fill;
    final orbs = [
      [size.width * 0.85, size.height * 0.08, 160.0, 0.05],
      [size.width * 0.1,  size.height * 0.3,  120.0, 0.04],
      [size.width * 0.7,  size.height * 0.6,  100.0, 0.03],
    ];
    for (final c in orbs) {
      final p = 1.0 + 0.08 * math.sin(progress * 2 * math.pi);
      final r = (c[2] as double) * p;
      paint.shader = RadialGradient(colors: [
        accent.withOpacity(c[3] as double),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(c[0] as double, c[1] as double), radius: r));
      canvas.drawCircle(Offset(c[0] as double, c[1] as double), r, paint);
    }
    paint.shader = null;
    final line = Paint()
      ..color = accent.withOpacity(0.025)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 18; i++) {
      final y = size.height * i / 18;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.progress != progress;
}
