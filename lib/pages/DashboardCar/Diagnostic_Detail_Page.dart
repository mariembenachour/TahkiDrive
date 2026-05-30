import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tahki_drive1/services/dashboard_service.dart';
import 'package:tahki_drive1/services/notification_service.dart';
import 'package:tahki_drive1/services/garage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
// ============================================
// CODES MÉCANIQUES (diagnostic IA disponible)
// ============================================
const Set<int> kMechanicalCodes = {
  32, 33, 34, 35, 36, 37, 38, 39,
  40, 41, 42, 43, 44, 45, 46, 47,
  48, 50, 52,
};

// ============================================
// PAGE PRINCIPALE
// ============================================

class DiagnosticDetailPage extends StatefulWidget {
  final int eventId;
  final String cin;
  final Map<String, dynamic>? quickData;

  const DiagnosticDetailPage({
    required this.eventId,
    required this.cin,
    this.quickData,
    super.key,
  });

  @override
  State<DiagnosticDetailPage> createState() => _DiagnosticDetailPageState();
}

class _DiagnosticDetailPageState extends State<DiagnosticDetailPage>
    with TickerProviderStateMixin {

  // ============================================
  // CONSTANTES
  // ============================================

  static const Color _kPurple     = Color(0xFF7C4DFF);
  static const Color _kPurpleDeep = Color(0xFF4A00D4);
  static const Color _kBlue       = Color(0xFF2979FF);
  static const Color _kBlueLight  = Color(0xFF82B1FF);
  static const Color _kBg         = Color(0xFF0D0B1E);
  static const Color _kBgMid      = Color(0xFF13102A);
  static const Color _kCard       = Color(0xFF1C1836);
  static const Color _kCardBorder = Color(0xFF2D2750);
  int _speechPosition = 0;        // position (en chars) où on a stoppé
  String _lastSpeechText = '';
  static const Map<String, Color> _sevPrimary = {
    'critical': Color(0xFFFF4444),
    'warning':  Color(0xFFFF8C00),
    'info':     Color(0xFF2979FF),
  };
  static const Map<String, Color> _sevLight = {
    'critical': Color(0xFF2A0A0A),
    'warning':  Color(0xFF1F1200),
    'info':     Color(0xFF0A1530),
  };
  static const Map<String, Color> _sevGlow = {
    'critical': Color(0x55FF4444),
    'warning':  Color(0x55FF8C00),
    'info':     Color(0x552979FF),
  };

  // ============================================
  // ÉTATS
  // ============================================

  Map<String, dynamic>? _diagnostic;
  List<dynamic> _garages        = [];
  bool   _isLoading             = true;
  bool   _isLoadingGarages      = false;
  bool   _isPlaying             = false;
  String? _playingKey;
  bool   _garagesLoaded         = false;
  int    _retryCount            = 0;

  static const int      _maxRetries = 4;
  static const Duration _retryDelay = Duration(seconds: 3);

  // ============================================
  // ANIMATIONS
  // ============================================

  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _garageCtrl;
  late AnimationController _carCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _fabCtrl;
  late AnimationController _card3dCtrl;
  late AnimationController _orbCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _garageAnim;
  late Animation<double> _carFloatAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _card3dAnim;
  late Animation<double> _orbAnim;
// ── TTS LOCAL (comme maintenance_diagnostic_page) ──
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _ttsCompleter;
  bool _ttsIsStopped = false;
  int _lastSentenceIndex = 0;
  List<String> _ttsSentences = [];
  // ============================================
  // GETTERS
  // ============================================
  static const Set<int> kInfoOnlyCodes = {
    0, 4, 17, 18, 19, 31
  };
  bool get _isMechanical {
    final code = int.tryParse(
        widget.quickData?['code']?.toString() ?? '') ?? 0;
    return kMechanicalCodes.contains(code);
  }
  bool get _isInfoOnly {
    final code = int.tryParse(
        widget.quickData?['code']?.toString() ?? '') ?? 0;
    return kInfoOnlyCodes.contains(code);
  }
  Color get _pc =>
      _sevPrimary[_diagnostic?['severity'] ?? 'warning'] ??
          _sevPrimary['warning']!;
  Color get _lc =>
      _sevLight[_diagnostic?['severity'] ?? 'warning'] ??
          _sevLight['warning']!;
  Color get _gc =>
      _sevGlow[_diagnostic?['severity'] ?? 'warning'] ??
          _sevGlow['warning']!;

  double get _ratio {
    switch (_diagnostic?['severity'] ?? 'warning') {
      case 'critical': return 1.0;
      case 'warning':  return 0.6;
      default:         return 0.3;
    }
  }

  String get _sevLabel {
    switch (_diagnostic?['severity'] ?? 'warning') {
      case 'critical': return 'CRITIQUE';
      case 'warning':  return 'ATTENTION';
      default:         return 'INFO';
    }
  }

  IconData get _sevIcon {
    switch (_diagnostic?['severity'] ?? 'warning') {
      case 'critical': return Icons.error_rounded;
      case 'warning':  return Icons.warning_amber_rounded;
      default:         return Icons.info_rounded;
    }
  }

  String get _panneName {
    final diagLabel = _diagnostic?['label']?.toString().trim() ?? '';
    if (diagLabel.isNotEmpty && diagLabel != 'Alerte') return diagLabel;
    final quickTitle = widget.quickData?['title']?.toString().trim() ?? '';
    if (quickTitle.isNotEmpty) return quickTitle;
    return 'Alerte véhicule';
  }

  List<Map<String, dynamic>> get _predictions {
    if (!_isMechanical && _diagnostic?['predictions'] != null) {
      return List<Map<String, dynamic>>.from(_diagnostic!['predictions']);
    }
    final sev = _diagnostic?['severity'] ?? 'warning';
    final h   = _diagnostic?['urgency_hours'] ?? 24;

    if (sev == 'critical') {
      return [
        {'delay': 'Dans ${h}h',   'msg': 'Risque d\'immobilisation totale du véhicule',      'sev': 'critical'},
        {'delay': 'Dans 48h',     'msg': 'Dommages irréversibles sur les composants liés',    'sev': 'warning'},
        {'delay': 'Dans 1 sem.',  'msg': 'Réparation très coûteuse, remplacement probable',   'sev': 'info'},
      ];
    } else if (sev == 'warning') {
      return [
        {'delay': 'Dans ${h}h',   'msg': 'Dégradation accélérée des pièces adjacentes',       'sev': 'warning'},
        {'delay': 'Dans 1 sem.',  'msg': 'Panne possible en route, risque de blocage',         'sev': 'warning'},
        {'delay': 'Dans 1 mois',  'msg': 'Coût de réparation multiplié par 2 à 3',            'sev': 'info'},
      ];
    }
    return [
      {'delay': 'Dans 1 mois',  'msg': 'Usure prématurée si non traité', 'sev': 'info'},
      {'delay': 'Dans 3 mois',  'msg': 'Risque de panne mineure',        'sev': 'info'},
    ];
  }

  // ============================================
  // CYCLE DE VIE
  // ============================================

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTts();
    _loadDiagnostic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _disposeAnimations();
    // Stopper le TTS local proprement
    _ttsIsStopped = true;
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    _tts.stop();
    super.dispose();
  }

  // ============================================
  // ANIMATIONS
  // ============================================

  void _initAnimations() {
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
    _garageCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _carCtrl     = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _particleCtrl= AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _rotateCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _fabCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _card3dCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _orbCtrl     = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

    _pulseAnim    = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl,  curve: Curves.easeInOut));
    _slideAnim    = CurvedAnimation(parent: _slideCtrl,  curve: Curves.easeOutCubic);
    _garageAnim   = CurvedAnimation(parent: _garageCtrl, curve: Curves.easeOutBack);
    _carFloatAnim = Tween<double>(begin: -10.0, end: 10.0).animate(CurvedAnimation(parent: _carCtrl,   curve: Curves.easeInOut));
    _shimmerAnim  = Tween<double>(begin: -2.0,  end: 2.0).animate(CurvedAnimation(parent: _shimmerCtrl,curve: Curves.easeInOut));
    _rotateAnim   = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_rotateCtrl);
    _fabScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut));
    _card3dAnim   = Tween<double>(begin: -0.04, end: 0.04).animate(CurvedAnimation(parent: _card3dCtrl, curve: Curves.easeInOut));
    _orbAnim      = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));
  }
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
  void _disposeAnimations() {
    for (final c in [
      _pulseCtrl, _slideCtrl, _garageCtrl, _carCtrl,
      _particleCtrl, _shimmerCtrl, _rotateCtrl, _fabCtrl,
      _card3dCtrl, _orbCtrl,
    ]) { c.dispose(); }
  }

  // ============================================
  // DONNÉES
  // ============================================
  Future<void> _loadDiagnostic() async {
    _lastSentenceIndex = 0;
    _ttsSentences = [];
    await _stopLocal();
    if (mounted) setState(() { _isPlaying = false; _playingKey = null; });

    setState(() { _isLoading = true; _retryCount = 0; });

    Map<String, dynamic>? diag;
    if (_isMechanical) {
      diag = await _fetchWithRetry();
    } else {
      diag = _buildBehaviorDiagnostic();
    }

    if (!mounted) return;
    setState(() { _diagnostic = diag; _isLoading = false; });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final fullText = _buildFullPageSpeech();
    if (fullText.isNotEmpty) {
      _ttsSentences = fullText
          .split(RegExp(r'\.\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      _speakFromIndex(0);
    }

    _fabCtrl.forward();
    if (_isMechanical) _loadGarages();
  }
  Future<void> _speakFromIndex(int startIndex) async {
    _ttsIsStopped = false;
    // Stopper proprement
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || _ttsIsStopped) return;

    final parts = _ttsSentences;
    final from = startIndex.clamp(0, parts.isEmpty ? 0 : parts.length - 1);

    setState(() { _isPlaying = true; _playingKey = 'full_page'; });

    for (int i = from; i < parts.length; i++) {
      if (_ttsIsStopped) break;
      _lastSentenceIndex = i;
      final sentence = parts[i].trim();
      if (sentence.isEmpty) continue;

      _ttsCompleter = Completer<void>();
      await _tts.speak(sentence);
      await _ttsCompleter!.future;

      if (_ttsIsStopped) break;
    }

    if (!_ttsIsStopped) _lastSentenceIndex = 0; // fin naturelle → reset
    if (mounted) setState(() { _isPlaying = false; _playingKey = null; });
  }

  Future<void> _stopLocal() async {
    _ttsIsStopped = true;
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
  }
  Map<String, dynamic> _buildBehaviorDiagnostic() {
    final code  = int.tryParse(widget.quickData?['code']?.toString() ?? '') ?? 0;
    final title = widget.quickData?['title']?.toString() ?? 'Alerte conduite';
    final description = widget.quickData?['car_voice']?.toString()
        ?? widget.quickData?['description']?.toString() ?? '';

    String severity = 'warning';
    if ([1, 2, 3, 12, 30].contains(code)) severity = 'critical';
    if ([17, 18, 29].contains(code))      severity = 'info';

    final Map<int, Map<String, dynamic>> behaviorData = {
      9: {
        'voice': 'Pose ce téléphone ! Je te surveille et c\'est dangereux. On en reparle quand on sera bien garé. 📱',
        'diagnosis': 'Distraction au volant détectée : utilisation de téléphone portable pendant la conduite.',
        'cause': 'Le conducteur a détourné son attention de la route pour consulter ou manipuler son téléphone.',
        'action_required': 'Rangez immédiatement votre téléphone. Si l\'appel est urgent, garez-vous en lieu sûr.',
        'estimated_risk': 'Risque de collision multiplié par 4. Perte de réaction de 1.5 secondes minimum.',
        'predictions': [
          {'delay': 'Dans 30s',  'msg': 'Distraction prolongée = risque de sortie de voie', 'sev': 'warning'},
          {'delay': 'Dans 2min', 'msg': 'Réaction d\'urgence fortement compromise',          'sev': 'critical'},
          {'delay': 'Dans 5min', 'msg': 'Accident probable si comportement persiste',         'sev': 'critical'},
        ],
      },
      12: {
        'voice': 'Hé ! Mes capteurs détectent que tu t\'endors. Arrête-toi, une pause café s\'impose vraiment ! ☕',
        'diagnosis': 'Fatigue conducteur détectée : signes d\'endormissement ou baisse de vigilance.',
        'cause': 'Conduite prolongée sans pause, manque de sommeil ou monotonie de la route.',
        'action_required': 'ARRÊTEZ IMMÉDIATEMENT le véhicule en lieu sûr. Faites une pause de 15-20 minutes minimum.',
        'estimated_risk': 'Micro-sommeil possible. 20% des accidents mortels sont liés à la fatigue.',
        'predictions': [
          {'delay': 'Dans 2min',  'msg': 'Risque de micro-sommeil critique',              'sev': 'critical'},
          {'delay': 'Dans 5min',  'msg': 'Perte de contrôle du véhicule probable',        'sev': 'critical'},
          {'delay': 'Dans 15min', 'msg': 'Accident grave quasi-certain',                  'sev': 'critical'},
        ],
      },
      14: {
        'voice': 'Ta ceinture ! Je refuse de bouger sans que tu sois attaché correctement. C\'est pour ta sécurité ! 🛡️',
        'diagnosis': 'Ceinture de sécurité non bouclée détectée.',
        'cause': 'Le conducteur ou passager n\'a pas attaché sa ceinture de sécurité.',
        'action_required': 'Bouclez immédiatement votre ceinture de sécurité avant tout déplacement.',
        'estimated_risk': 'Risque de projection hors du véhicule en cas de choc. Réduction de 50% des chances de survie.',
        'predictions': [
          {'delay': 'Immédiat',  'msg': 'Non-respect = risque vital en cas de freinage brusque', 'sev': 'critical'},
          {'delay': 'Tout trajet','msg': 'Amende possible + danger permanent',                    'sev': 'warning'},
        ],
      },
      22: {
        'voice': 'Lève le pied ! Tu dépasses la limite et je n\'aime pas ça du tout. On n\'est pas en Formule 1 ! 🏎️',
        'diagnosis': 'Excès de vitesse détecté : dépassement de la limite autorisée.',
        'cause': 'Le conducteur maintient une vitesse supérieure à la réglementation en vigueur.',
        'action_required': 'Réduisez immédiatement votre vitesse pour respecter les limites.',
        'estimated_risk': 'Distance de freinage augmentée, perte de contrôle en virage, amende et retrait de points.',
        'predictions': [
          {'delay': 'Dans 1min',  'msg': 'Risque de perte de contrôle accru',              'sev': 'warning'},
          {'delay': 'Dans 5min',  'msg': 'Radar possible + danger pour les autres usagers', 'sev': 'warning'},
          {'delay': 'Long terme', 'msg': 'Retrait de permis si récidive',                   'sev': 'info'},
        ],
      },
      23: {
        'voice': 'Doucement sur l\'accélérateur... T\'as l\'air pressé mais ta sécurité passe avant tout. 🚗',
        'diagnosis': 'Accélération excessive détectée : changement de vitesse trop brusque.',
        'cause': 'Le conducteur accélère de manière trop agressive, stress ou impatience.',
        'action_required': 'Adoptez une conduite plus douce et progressive.',
        'estimated_risk': 'Usure prématurée du moteur et transmission, surconsommation de carburant.',
        'predictions': [
          {'delay': 'Dans 1 sem.', 'msg': 'Usure accélérée embrayage/boîte',        'sev': 'warning'},
          {'delay': 'Dans 1 mois', 'msg': 'Coût réparation transmission +30%',       'sev': 'info'},
        ],
      },
      24: {
        'voice': 'Freinage brusque ! Anticipe un peu plus, mes amortisseurs te remercieront. 🛞',
        'diagnosis': 'Freinage brusque détecté : décélération anormalement forte.',
        'cause': 'Manque d\'anticipation, distraction ou réaction tardive à un obstacle.',
        'action_required': 'Augmentez la distance de sécurité. Anticipez les freinages.',
        'estimated_risk': 'Usure rapide des plaquettes et disques, risque de collision par l\'arrière.',
        'predictions': [
          {'delay': 'Dans 1 sem.', 'msg': 'Usure plaquettes x2 plus rapide',    'sev': 'warning'},
          {'delay': 'Dans 1 mois', 'msg': 'Remplacement freins nécessaire',      'sev': 'warning'},
        ],
      },
      1: {
        'voice': 'DANGER ! Risque de collision détecté. Freine et reprends le contrôle maintenant ! 🚨',
        'diagnosis': 'Risque de collision frontale imminent détecté par les capteurs.',
        'cause': 'Véhicule ou obstacle trop proche sur la trajectoire. Vitesse inadaptée.',
        'action_required': 'FREINEZ IMMÉDIATEMENT et ÉVITEZ si possible. Maintenez le contrôle.',
        'estimated_risk': 'Collision grave probable. Risque vital pour occupants et autres usagers.',
        'predictions': [
          {'delay': 'Dans 2s', 'msg': 'Impact imminent si aucune action',                       'sev': 'critical'},
          {'delay': 'Dans 5s', 'msg': 'Collision inévitable sans freinage d\'urgence',           'sev': 'critical'},
        ],
      },
      2: {
        'voice': 'Attention piéton ! Ralentis immédiatement, quelqu\'un traverse devant nous ! 🚶',
        'diagnosis': 'Piéton détecté sur la trajectoire du véhicule.',
        'cause': 'Personne traversant ou présente sur la chaussée dans la zone de danger.',
        'action_required': 'RALENTISSEZ immédiatement et PRÉPAREZ-VOUS à arrêter.',
        'estimated_risk': 'Accident mortel pour le piéton. Responsabilité pénale du conducteur.',
        'predictions': [
          {'delay': 'Dans 3s',  'msg': 'Impact piéton si vitesse maintenue', 'sev': 'critical'},
          {'delay': 'Dans 10s', 'msg': 'Traversée complète si ralentissement','sev': 'info'},
        ],
      },
      3: {
        'voice': 'Tu sors de ta voie ! Regardes la route et reste dans ton couloir. 🛣️',
        'diagnosis': 'Sortie de voie détectée : véhicule quitte sa ligne sans clignotant.',
        'cause': 'Distraction, fatigue ou manque de concentration du conducteur.',
        'action_required': 'Recentrez immédiatement le véhicule. Vérifiez vos rétroviseurs.',
        'estimated_risk': 'Collision latérale, sortie de route, tonneau possible.',
        'predictions': [
          {'delay': 'Dans 5s',  'msg': 'Sortie de route si non corrigé',    'sev': 'critical'},
          {'delay': 'Dans 30s', 'msg': 'Risque de collision latérale',      'sev': 'warning'},
        ],
      },
      11: {
        'voice': 'Concentration ! Tu es distrait et ça m\'inquiète vraiment beaucoup. 👀',
        'diagnosis': 'Distraction conducteur détectée : attention détournée de la route.',
        'cause': 'Le conducteur regarde ailleurs que sur la route.',
        'action_required': 'Recentrez votre attention sur la route. Les yeux devant !',
        'estimated_risk': 'Réaction retardée, risque de collision ou sortie de route.',
        'predictions': [
          {'delay': 'Dans 10s', 'msg': 'Obstacle non vu = accident probable',    'sev': 'warning'},
          {'delay': 'Dans 1min','msg': 'Risque cumulé avec la fatigue',           'sev': 'warning'},
        ],
      },
      10: {
        'voice': 'Arrête de fumer en conduisant, c\'est dangereux pour toi et ta distraction. 🚭',
        'diagnosis': 'Fumée détectée dans l\'habitacle pendant la conduite.',
        'cause': 'Cigarette ou objet fumant manipulé par le conducteur.',
        'action_required': 'Éteignez immédiatement la cigarette. Concentrez-vous sur la route.',
        'estimated_risk': 'Distraction + risque incendie. Odeur persistante dans l\'habitacle.',
        'predictions': [
          {'delay': 'Immédiat',   'msg': 'Distraction visuelle et manuelle',  'sev': 'warning'},
          {'delay': 'Long terme', 'msg': 'Détérioration intérieur véhicule',  'sev': 'info'},
        ],
      },
      29: {
        'voice': 'Je tourne pour rien là ! Éteins le moteur si tu t\'arrêtes, j\'économise le carburant. ⏱️',
        'diagnosis': 'Ralenti prolongé détecté : moteur tourne à l\'arrêt depuis trop longtemps.',
        'cause': 'Oubli d\'extinction du moteur lors d\'un arrêt prolongé.',
        'action_required': 'Éteignez le moteur si l\'arrêt dépasse 30 secondes.',
        'estimated_risk': 'Surconsommation carburant, usure moteur inutile, pollution.',
        'predictions': [
          {'delay': 'Dans 5min',  'msg': 'Consommation inutile de 0.5L/10min',   'sev': 'info'},
          {'delay': 'Dans 30min', 'msg': 'Usure moteur et surchauffe possible',   'sev': 'warning'},
        ],
      },
      30: {
        'voice': 'IMPACT détecté ! Est-ce que tu vas bien ? Arrête-toi et vérifie le véhicule maintenant. 🆘',
        'diagnosis': 'Impact physique détecté sur le véhicule. Collision ou choc enregistré.',
        'cause': 'Contact avec un objet, véhicule ou obstacle. Accident potentiel.',
        'action_required': 'ARRÊTEZ immédiatement en lieu sûr. Vérifiez l\'état du véhicule et des occupants.',
        'estimated_risk': 'Dommages structurels cachés, fuite fluide, danger immédiat.',
        'predictions': [
          {'delay': 'Immédiat', 'msg': 'Vérification sécurité occupants',                     'sev': 'critical'},
          {'delay': 'Dans 5min','msg': 'Inspection véhicule obligatoire',                      'sev': 'critical'},
          {'delay': 'Dans 1h',  'msg': 'Appel assurance/dépanneur si dommages',               'sev': 'warning'},
        ],
      },
      // Ajoute dans behaviorData map :
      17: {
        'voice': 'Moteur démarré ! Prêt pour une nouvelle aventure ensemble 🚗',
        'diagnosis': 'Démarrage du véhicule enregistré.',
        'cause': 'Le conducteur a démarré le moteur.',
        'action_required': 'Aucune action requise.',
        'estimated_risk': 'Aucun risque détecté.',
        'predictions': [
          {'delay': 'Normal', 'msg': 'Démarrage nominal, bonne route !', 'sev': 'info'},
        ],
      },
      18: {
        'voice': 'Moteur éteint. Bonne journée, on se retrouve bientôt ! 👋',
        'diagnosis': 'Arrêt du véhicule enregistré.',
        'cause': 'Le conducteur a coupé le moteur.',
        'action_required': 'Aucune action requise.',
        'estimated_risk': 'Aucun risque détecté.',
        'predictions': [
          {'delay': 'Normal', 'msg': 'Arrêt nominal.', 'sev': 'info'},
        ],
      },
      51: {
        'voice': 'Mon réservoir est bas ! Pense à faire le plein bientôt ⛽',
        'cause': 'Consommation normale — réservoir à remplir.',
        'action_required': 'Faites le plein dès que possible.',
        'estimated_risk': 'Risque de panne sèche si non traité.',
        'predictions': [
          {'delay': 'Immédiat',   'msg': 'Autonomie réduite — prévoir le plein', 'sev': 'warning'},
          {'delay': 'Dans 50km', 'msg': 'Risque de panne sèche',                'sev': 'critical'},
        ],
      },
      4: {
        'voice': 'Zone de sécurité virtuelle déclenchée. Conduis prudemment 🛡️',
        'diagnosis': 'Alerte zone tampon virtuelle.',
        'cause': 'Proximité détectée avec un obstacle ou zone définie.',
        'action_required': 'Réduisez la vitesse et restez vigilant.',
        'estimated_risk': 'Risque de collision si non corrigé.',
        'predictions': [
          {'delay': 'Immédiat', 'msg': 'Maintenir distance de sécurité', 'sev': 'warning'},
        ],
      },
      31: {
        'voice': 'Mouvement suspect détecté sur moi ! Tu n\'es pas là ? 🚨',
        'diagnosis': 'Mouvement ou manipulation anormale du boîtier détectée.',
        'cause': 'Tentative de manipulation ou mouvement non autorisé du véhicule.',
        'action_required': 'Vérifiez que votre véhicule est en sécurité.',
        'estimated_risk': 'Risque de vol ou sabotage.',
        'predictions': [
          {'delay': 'Immédiat', 'msg': 'Vérifier le véhicule immédiatement', 'sev': 'critical'},
        ],
      },
    };

    final data = behaviorData[code] ?? {
      'voice': widget.quickData?['car_voice']?.toString().isNotEmpty == true
          ? widget.quickData!['car_voice'].toString()
          : 'Événement enregistré par mes capteurs ',
      'diagnosis':       'Événement de conduite enregistré par le système.',
      'cause':           'Données transmises par le boîtier télématique.',
      'action_required': 'Aucune action immédiate requise.',
      'estimated_risk':  'Risque faible.',
      'predictions': [
        {'delay': 'Normal', 'msg': 'Surveillance continue active', 'sev': 'info'},
      ],
    };

    return {
      'code':             code,
      'label':            title,
      'severity':         severity,
      'car_voice':        data['voice'] as String,
      'diagnosis':        data['diagnosis'],
      'cause':            data['cause'],
      'action_required':  data['action_required'],
      'estimated_risk':   data['estimated_risk'],
      'urgency_hours':    severity == 'critical' ? 0 : 24,
      'predictions':      data['predictions'],
    };
  }

  Future<Map<String, dynamic>?> _fetchWithRetry() async {
    while (_retryCount <= _maxRetries) {
      final diag      = await NotificationService.fetchDiagnostic(widget.eventId, widget.cin);
      final diagnosis = diag?['diagnosis']?.toString().trim()      ?? '';
      final cause     = diag?['cause']?.toString().trim()          ?? '';
      final action    = diag?['action_required']?.toString().trim() ?? '';

      final isReal = diagnosis.isNotEmpty &&
          diagnosis != 'Diagnostic en cours de génération par l\'IA...' &&
          cause.isNotEmpty     && cause != 'Analyse en cours' &&
          action.isNotEmpty    && action != 'Consultez votre mécanicien';

      if (isReal) return diag;

      _retryCount++;
      if (_retryCount > _maxRetries) break;
      await Future.delayed(_retryDelay);
    }
    return await NotificationService.fetchDiagnostic(widget.eventId, widget.cin);
  }

  Future<void> _loadGarages() async {
    if (!mounted) return;
    setState(() => _isLoadingGarages = true);
    try {
      // Récupérer la position depuis le backend
      final location = await DashService.fetchLocation();

      List<dynamic> result = [];

      if (location != null &&
          location['latitude'] != null &&
          location['longitude'] != null) {
        final lat = double.tryParse(location['latitude'].toString());
        final lon = double.tryParse(location['longitude'].toString());

        if (lat != null && lon != null) {
          result = await GarageService.getNearestGarages(
            latitude: lat,
            longitude: lon,
            limit: 5,
          );
        }
      }

      // Fallback si pas de position ou aucun résultat
      if (result.isEmpty) {
        result = await GarageService.getAllGarages(limit: 5);
      }

      if (!mounted) return;
      setState(() {
        _garages          = result;
        _isLoadingGarages = false;
        _garagesLoaded    = true;
      });
      _garageCtrl.forward();
    } catch (_) {
      try {
        final fallback = await GarageService.getAllGarages(limit: 5);
        if (!mounted) return;
        setState(() {
          _garages          = fallback;
          _isLoadingGarages = false;
          _garagesLoaded    = true;
        });
        _garageCtrl.forward();
      } catch (e) {
        if (mounted) setState(() => _isLoadingGarages = false);
      }
    }
  }

  // ============================================
  // VOIX — lit TOUTE la page
  // ============================================

  /// Appelé par le FAB et le bouton "Réécouter" : stop ou rejouer toute la page
  void _toggleVoice() async {
    if (_isPlaying) {
      // Sauvegarder l'index AVANT de stopper
      final savedIndex = _lastSentenceIndex;
      await _stopLocal();
      _lastSentenceIndex = savedIndex; // restaurer car _stopLocal ne le touche pas
      if (mounted) setState(() { _isPlaying = false; _playingKey = null; });
    } else {
      await _stopLocal();
      final fullText = _buildFullPageSpeech();
      if (fullText.isEmpty) return;

      // Découper en phrases une seule fois
      _ttsSentences = fullText
          .split(RegExp(r'\.\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      _speakFromIndex(_lastSentenceIndex);
    }
  }

  /// Lit un paragraphe individuel (petits boutons volume sur chaque section)
  Future<void> _speakParagraph(String key, String text) async {
    // Si ce paragraphe joue déjà → STOP
    if (_playingKey == key && _isPlaying) {
      await _stopLocal();
      if (mounted) setState(() { _isPlaying = false; _playingKey = null; });
      return;
    }

    // Stopper tout ce qui tourne
    await _stopLocal();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    setState(() { _isPlaying = true; _playingKey = key; });

    _ttsIsStopped = false;
    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    await _ttsCompleter!.future;

    if (mounted && _playingKey == key && !_ttsIsStopped) {
      setState(() { _isPlaying = false; _playingKey = null; });
    }
  }

  /// Construit le texte complet de toute la page pour la voix
  String _buildFullPageSpeech() {
    final parts = <String>[];

    // 1. Titre + sévérité
    parts.add(_panneName);
    parts.add('Niveau de risque : $_sevLabel');

    // 2. Voix de la voiture
    final carVoice = _diagnostic?['car_voice']?.toString().trim() ?? '';
    if (carVoice.isNotEmpty) parts.add(carVoice);

    // 3. Diagnostic
    final diagnosis = _field('diagnosis', [
      'Diagnostic en cours de génération par l\'IA...',
      'Analyse en cours',
      'Événement de conduite détecté par le système de surveillance.',
    ]);
    if (diagnosis != null) parts.add('Diagnostic : $diagnosis');

    final cause = _field('cause', [
      'Analyse en cours', 'En cours d\'évaluation',
      'Comportement de conduite nécessitant attention.',
    ]);
    if (cause != null) parts.add('Cause probable : $cause');

    final action = _field('action_required', [
      'Consultez votre mécanicien', 'Consulter un mécanicien',
      'Adaptez votre conduite selon les recommandations.',
    ]);
    if (action != null) parts.add('Action requise : $action');

    // 4. Prédictions
    final preds = _predictions;
    if (preds.isNotEmpty) {
      parts.add('Prédictions si rien n\'est fait :');
      for (final p in preds) {
        final sev = p['sev'] as String;
        final sevTxt = sev == 'critical' ? 'Critique' : sev == 'warning' ? 'Attention' : 'Info';
        parts.add('${p['delay']} — $sevTxt : ${p['msg']}');
      }
    }

    // 5. Risque estimé (mécanique seulement)
    if (_isMechanical) {
      final risk = _field('estimated_risk', [
        'Risque inconnu — consultez un professionnel',
        'Risque de dommages si non traité',
      ]);
      if (risk != null) parts.add('Risque estimé : $risk');
    }

    return parts.join('. ');
  }

  // ============================================
  // UTILITAIRES
  // ============================================

  String? _field(String key, List<String> fallbacks) {
    final val = _diagnostic?[key]?.toString().trim() ?? '';
    if (val.isEmpty) return null;
    for (final f in fallbacks) { if (val == f) return null; }
    return val;
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: !_isLoading ? _buildVoiceFAB() : null,
      body: _isLoading ? _buildLoader() : _buildBody(),
    );
  }

  // ============================================
  // VOICE FAB
  // ============================================

  Widget _buildVoiceFAB() {
    return ScaleTransition(
      scale: _fabScaleAnim,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: _isPlaying ? (0.96 + 0.04 * _pulseAnim.value) : 1.0,
          child: GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _isPlaying
                      ? [_kPurple, _kPurpleDeep]
                      : [const Color(0xFF251E4A), const Color(0xFF1A1535)],
                  center: Alignment.topLeft, radius: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPlaying ? _kPurple.withOpacity(0.6) : Colors.black.withOpacity(0.5),
                    blurRadius: _isPlaying ? 28 : 16,
                    spreadRadius: _isPlaying ? 4 : 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(color: _kPurple.withOpacity(0.15), blurRadius: 2, offset: const Offset(-2, -2)),
                ],
                border: Border.all(
                  color: _isPlaying ? _kPurple.withOpacity(0.8) : _kCardBorder,
                  width: 1.5,
                ),
              ),
              child: Stack(alignment: Alignment.center, children: [
                if (_isPlaying)
                  _AudioWaveBars(isPlaying: true, color: Colors.white),
                if (!_isPlaying)
                  const Icon(Icons.volume_up_rounded, color: _kPurple, size: 28),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // LOADER
  // ============================================

  Widget _buildLoader() {
    return Stack(children: [
      _buildBg(),
      Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: Listenable.merge([_carFloatAnim, _rotateAnim, _orbAnim]),
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _carFloatAnim.value),
              child: _build3DCarOrb(size: 120, iconSize: 60),
            ),
          ),
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFB39DDB), Color(0xFFFFFFFF), Color(0xFF7C4DFF)],
            ).createShader(b),
            child: Text('analyse_ia_en_cours'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text('L\'IA diagnostique votre véhicule',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: _kPurple.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _build3DCarOrb({double size = 90, double iconSize = 44}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _card3dAnim, _rotateAnim]),
      builder: (_, __) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(_card3dAnim.value)
          ..rotateX(_card3dAnim.value * 0.5)
          ..scale(_pulseAnim.value),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [_kPurple, _kBlue, _kPurpleDeep, _kPurple],
              startAngle: _rotateAnim.value,
              endAngle: _rotateAnim.value + 2 * math.pi,
            ),
            boxShadow: [
              BoxShadow(color: _kPurple.withOpacity(0.6), blurRadius: 40, spreadRadius: 8, offset: const Offset(0, 10)),
              BoxShadow(color: _kBlue.withOpacity(0.3),   blurRadius: 20, spreadRadius: 2, offset: const Offset(-5, -5)),
            ],
          ),
          child: Icon(Icons.directions_car_rounded, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }

  // ============================================
  // BACKGROUND
  // ============================================

  Widget _buildBg() {
    return AnimatedBuilder(
      animation: Listenable.merge([_particleCtrl, _rotateAnim]),
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(_particleCtrl.value, _rotateAnim.value, _kPurple),
        child: Container(),
      ),
    );
  }

  // ============================================
  // BODY
  // ============================================

  Widget _buildBody() {
    return Stack(children: [
      _buildBg(),
      CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _slideAnim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(_slideAnim),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 20),
                    _buildBehaviorVoiceCard(),
                    const SizedBox(height: 16),
                    _buildDiagnosticCard(),
                    const SizedBox(height: 16),
                    _buildRiskMeter(),
                    const SizedBox(height: 16),
                    _buildPredictions(),
                    if (_isMechanical) ...[
                      const SizedBox(height: 20),
                      _buildMechanicsHeader(),
                      const SizedBox(height: 12),
                      _buildMechanicsList(),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  // ============================================
  // CARTE VOCALE
  // ============================================

  Widget _buildBehaviorVoiceCard() {
    final carVoice = _diagnostic?['car_voice']?.toString().trim() ?? '';
    if (carVoice.isEmpty) return const SizedBox.shrink();

    final isCritical   = (_diagnostic?['severity'] ?? '') == 'critical';
    final severityColor= isCritical ? const Color(0xFFFF4444) : _pc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [severityColor.withOpacity(0.15), _kPurple.withOpacity(0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: severityColor.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: _gc.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icône animée
            Transform.scale(
              scale: _isPlaying ? (0.95 + 0.05 * _pulseAnim.value) : 1.0,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2), shape: BoxShape.circle,
                  border: Border.all(color: severityColor.withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: _gc, blurRadius: 12)],
                ),
                child: _isPlaying
                    ? _AudioWaveBars(isPlaying: true, color: severityColor)
                    : Icon(isCritical ? Icons.warning_rounded : _sevIcon, color: severityColor, size: 26),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _PulsingDot(color: severityColor),
                  const SizedBox(width: 6),
                  Text(
                    _isMechanical ? 'MA VOITURE PARLE' : 'ALERTE CONDUITE',
                    style: TextStyle(color: severityColor, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.4),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(carVoice,
                    style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 14, height: 1.6, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                if (!_isMechanical)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: severityColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      isCritical ? '⚠️ CRITIQUE' : '⚡ ATTENTION',
                      style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                const SizedBox(height: 12),
                // Bouton Réécouter/Arrêter TOUTE la page
                GestureDetector(
                  onTap: _toggleVoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: severityColor.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                        color: severityColor, size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlaying ? 'Arrêter' : 'Réécouter tout',
                        style: TextStyle(color: severityColor, fontSize: 12, fontWeight: FontWeight.w700),
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

  // ============================================
  // APP BAR
  // ============================================

  SliverAppBar _buildAppBar() {
    final date = widget.quickData?['date'] ?? '';
    return SliverAppBar(
      expandedHeight: 240, pinned: true,
      backgroundColor: _kBgMid, elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: ShaderMask(
        shaderCallback: (b) => const LinearGradient(colors: [Colors.white, Color(0xFFB39DDB)]).createShader(b),
        child: Text(
          _isMechanical ? 'Diagnostic IA' : 'Détail Alerte',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
          ),
          child: IconButton(
            icon: Icon(Icons.refresh_rounded, color: _kPurple, size: 20),
            onPressed: _loadDiagnostic,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(background: _buildAppBarBackground(date)),
    );
  }

  Widget _buildAppBarBackground(String date) {
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kBg, _kBgMid, _lc.withOpacity(0.4)],
          ),
        ),
      ),
      Positioned(
        top: -60, right: -60,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnim, _rotateAnim]),
          builder: (_, __) => Transform.rotate(
            angle: _rotateAnim.value * 0.05,
            child: Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _pc.withOpacity(0.12), _kPurple.withOpacity(0.06), Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -40, left: -40,
        child: Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [_kBlue.withOpacity(0.08), Colors.transparent]),
          ),
        ),
      ),
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(painter: _GridPainter(_particleCtrl.value)),
        ),
      ),
      Positioned(
        right: 16, top: 60,
        child: AnimatedBuilder(
          animation: Listenable.merge([_carFloatAnim, _card3dAnim]),
          builder: (_, __) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_card3dAnim.value * 0.5)
              ..translate(0.0, _carFloatAnim.value * 0.3),
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  _pc.withOpacity(0.2), _kPurple.withOpacity(0.1), Colors.transparent,
                ]),
                shape: BoxShape.circle,
                border: Border.all(color: _pc.withOpacity(0.3), width: 1),
              ),
              child: Icon(_sevIcon, color: _pc, size: 44),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 100, 120, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _pc.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _pc.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: _gc, blurRadius: 12)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PulsingDot(color: _pc),
              const SizedBox(width: 6),
              Text(_sevLabel, style: TextStyle(color: _pc, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ]),
          ),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.85)]).createShader(b),
            child: Text(_panneName,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.15),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          if (date.isNotEmpty)
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(date, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ),
            ]),
        ]),
      ),
    ]);
  }

  // ============================================
  // DIAGNOSTIC CARD
  // ============================================

  Widget _buildDiagnosticCard() {
    final diagnosis = _field('diagnosis', [
      'Diagnostic en cours de génération par l\'IA...',
      'Analyse en cours',
      'Événement de conduite détecté par le système de surveillance.',
    ]);
    final cause  = _field('cause', ['Analyse en cours', 'En cours d\'évaluation', 'Comportement de conduite nécessitant attention.']);
    final action = _field('action_required', [
      'Consultez votre mécanicien', 'Consulter un mécanicien',
      'Adaptez votre conduite selon les recommandations.',
    ]);
    final cardTitle = _isMechanical ? 'DIAGNOSTIC IA' : 'ANALYSE COMPORTEMENT';
    final cardIcon  = _isMechanical ? Icons.biotech_rounded : Icons.psychology_rounded;
    final cardColor = _isMechanical ? _kPurple : const Color(0xFF00BCD4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _card3dAnim,
        builder: (_, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_card3dAnim.value * 0.3),
          child: child,
        ),
        child: _DarkCard(
          title: cardTitle, titleIcon: cardIcon, titleColor: cardColor, accentColor: cardColor,
          child: Column(children: [
            _DiagRow(icon: Icons.local_fire_department_rounded, color: _pc,
                label: 'Ce qui se passe', value: diagnosis,
                vocKey: 'diagnosis', playingKey: _playingKey,
                onVoc: diagnosis != null ? () => _speakParagraph('diagnosis', diagnosis) : null),
            _darkDivider(),
            _DiagRow(icon: Icons.search_rounded, color: const Color(0xFFFF8C00),
                label: 'Cause probable', value: cause,
                vocKey: 'cause', playingKey: _playingKey,
                onVoc: cause != null ? () => _speakParagraph('cause', cause) : null),
            _darkDivider(),
            _DiagRow(icon: Icons.build_rounded, color: const Color(0xFF00E676),
                label: 'Action immédiate', value: action,
                vocKey: 'action', playingKey: _playingKey,
                onVoc: action != null ? () => _speakParagraph('action', action) : null),
          ]),
        ),
      ),
    );
  }

  Widget _darkDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: _kCardBorder),
  );

  // ============================================
  // RISK METER
  // ============================================

  Widget _buildRiskMeter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _card3dAnim,
        builder: (_, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_card3dAnim.value * 0.2),
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kCardBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8)),
              BoxShadow(color: _gc.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_kPurple.withOpacity(0.3), _kBlue.withOpacity(0.2)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPurple.withOpacity(0.4)),
                ),
                child: const Icon(Icons.shield_rounded, color: _kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('niveau_de_risque'.tr(),
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _pc.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _pc.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: _gc, blurRadius: 10)],
                ),
                child: Text(_sevLabel, style: TextStyle(color: _pc, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _slideAnim,
              builder: (_, __) => Column(children: [
                Stack(children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _kCardBorder, width: 0.5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: _ratio * _slideAnim.value,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_kBlue, _kPurple, _pc]),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [BoxShadow(color: _gc, blurRadius: 12, spreadRadius: 1)],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['Faible', 'Modéré', 'Élevé', 'Critique'].map((l) {
                    final r = _ratio;
                    final active =
                        (l == 'Critique' && r == 1.0) ||
                            (l == 'Élevé'    && r >= 0.6 && r < 1.0) ||
                            (l == 'Modéré'   && r >= 0.3 && r < 0.6) ||
                            (l == 'Faible'   && r < 0.3);
                    return Text(l, style: TextStyle(
                      color: active ? _pc : Colors.white.withOpacity(0.2),
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                    ));
                  }).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_kPurple.withOpacity(0.25), _kBlue.withOpacity(0.15)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPurple.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.2), blurRadius: 16)],
                ),
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(colors: [_kPurple, _kBlueLight]).createShader(b),
                  child: Text('${(_ratio * 100).toInt()}% de risque',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ============================================
  // PREDICTIONS
  // ============================================

  Widget _buildPredictions() {
    final preds         = _predictions;
    final estimatedRisk = _isMechanical
        ? _field('estimated_risk', [
      'Risque inconnu — consultez un professionnel',
      'Risque de dommages si non traité',
    ])
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _DarkCard(
        title: 'PRÉDICTIONS', titleIcon: Icons.auto_graph_rounded,
        titleColor: _kBlue, accentColor: _kBlue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Si rien n\'est fait dans les délais recommandés :',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          ...preds.asMap().entries.map((e) => _PredRow(
            delay: e.value['delay'], msg: e.value['msg'], sev: e.value['sev'],
            index: e.key, vocKey: 'pred_${e.key}', playingKey: _playingKey,
            onVoc: () => _speakParagraph('pred_${e.key}', e.value['msg'] as String),
          )),
          if (estimatedRisk != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFFFF8C00).withOpacity(0.12),
                  const Color(0xFFFF8C00).withOpacity(0.06),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFFFF8C00), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(estimatedRisk,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.55)),
                ),
                const SizedBox(width: 8),
                _VocBtn(
                  isActive: _playingKey == 'estimated_risk', color: const Color(0xFFFF8C00),
                  onTap: () => _speakParagraph('estimated_risk', estimatedRisk),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ============================================
  // MÉCANICIENS
  // ============================================

  Widget _buildMechanicsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.car_repair_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.white, Color(0xFFB39DDB)]).createShader(b),
          child: Text('mecaniciens_proches'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final uri = Uri(scheme: 'tel', path: '197');
            if (await canLaunchUrl(uri)) launchUrl(uri);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444).withOpacity(0.12),
              border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.4)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFFF4444).withOpacity(0.2), blurRadius: 10)],
            ),
            child: const Row(children: [
              Icon(Icons.phone_rounded, color: Color(0xFFFF4444), size: 14),
              SizedBox(width: 5),
              Text('197', style: TextStyle(color: Color(0xFFFF4444), fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMechanicsList() {
    if (_isLoadingGarages && !_garagesLoaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2.5)),
      );
    }
    if (_garages.isEmpty) return _buildStaticGaragesList();

    return Column(
      children: _garages.asMap().entries.map((e) => AnimatedBuilder(
        animation: _garageAnim,
        builder: (_, child) => FadeTransition(
          opacity: _garageAnim,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, 0.08 * (e.key + 1)), end: Offset.zero).animate(_garageAnim),
            child: child,
          ),
        ),
        child: _buildGarageCard(e.value as Map<String, dynamic>),
      )).toList(),
    );
  }

  Widget _buildStaticGaragesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        _buildStaticGarageCard('Garage Central Tunis',   'Avenue Habib Bourguiba, Tunis', '+216 71 000 001', '2.1'),
        _buildStaticGarageCard('Auto Service Ariana',    'Route de la Marsa, Ariana',    '+216 71 000 002', '3.4'),
        _buildStaticGarageCard('Mécanicien Express',     'Rue de Carthage, Tunis',       '+216 71 000 003', '4.0'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final uri = Uri(scheme: 'tel', path: '197');
            if (await canLaunchUrl(uri)) launchUrl(uri);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.phone_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Appeler l\'assistance 197', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ])),
          ),
        ),
      ]),
    );
  }

  Widget _buildStaticGarageCard(String name, String addr, String phone, String dist) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_kPurple.withOpacity(0.2), _kBlue.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPurple.withOpacity(0.3)),
            ),
            child: const Icon(Icons.car_repair_rounded, color: _kPurple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(addr, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF00E676)),
                const SizedBox(width: 3),
                Text('~$dist km', style: const TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.5), blurRadius: 16)],
              ),
              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGarageCard(Map<String, dynamic> g) {
    final phone  = g['telephone']?.toString() ?? '';
    final name   = g['nom']?.toString()       ?? 'Garage';
    final addr   = g['adresse']?.toString()   ?? '';
    final dist   = g['distance_km'];
    final rating = g['rating'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_kPurple.withOpacity(0.2), _kBlue.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPurple.withOpacity(0.3)),
            ),
            child: const Icon(Icons.car_repair_rounded, color: _kPurple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (addr.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(addr, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(children: [
              if (dist != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF00E676)),
                    const SizedBox(width: 3),
                    Text('$dist km', style: const TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
              if (rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.star_rounded, size: 10, color: Color(0xFFFF8C00)),
                    const SizedBox(width: 3),
                    Text('$rating', style: const TextStyle(color: Color(0xFFFF8C00), fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ])),
          const SizedBox(width: 10),
          if (phone.isNotEmpty)
            GestureDetector(
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: phone);
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.5), blurRadius: 16)],
                ),
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
              ),
            )
          else
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _kPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _kPurple.withOpacity(0.3)),
              ),
              child: const Icon(Icons.location_on_rounded, color: _kPurple, size: 20),
            ),
        ]),
      ),
    );
  }
}

// ============================================
// PAINTERS
// ============================================

class _BgPainter extends CustomPainter {
  final double progress, rotate;
  final Color  accent;
  _BgPainter(this.progress, this.rotate, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0D0B1E), Color(0xFF13102A), Color(0xFF0F0E25)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final paint = Paint()..style = PaintingStyle.fill;
    final orbs = [
      [size.width * 0.85, size.height * 0.06, 180.0, 0.045],
      [size.width * 0.1,  size.height * 0.22, 130.0, 0.035],
      [size.width * 0.7,  size.height * 0.52, 120.0, 0.028],
      [size.width * 0.18, size.height * 0.72, 100.0, 0.022],
      [size.width * 0.88, size.height * 0.88,  80.0, 0.018],
    ];
    for (final c in orbs) {
      final pulse  = 1.0 + 0.08 * math.sin(progress * 2 * math.pi + (c[0] as double) * 0.01);
      final r      = (c[2] as double) * pulse;
      final gradient = RadialGradient(colors: [
        accent.withOpacity(c[3] as double),
        accent.withOpacity((c[3] as double) * 0.3),
        Colors.transparent,
      ]);
      paint.shader = gradient.createShader(Rect.fromCircle(center: Offset(c[0] as double, c[1] as double), radius: r));
      canvas.drawCircle(Offset(c[0] as double, c[1] as double), r, paint);
    }
    paint.shader = null;

    final linePaint = Paint()
      ..color = accent.withOpacity(0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 20; i++) {
      final y = (i * size.height / 20) + (progress * 30) % (size.height / 20);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(7);
    for (int i = 0; i < 30; i++) {
      final x     = rng.nextDouble() * size.width;
      final y     = rng.nextDouble() * size.height;
      final phase = (progress + i * 0.07) % 1.0;
      final op    = math.sin(phase * math.pi).clamp(0.0, 1.0) * 0.4;
      final r     = 0.8 + rng.nextDouble() * 1.5;
      dotPaint.color = accent.withOpacity(op);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }

    final wheelPaint = Paint()
      ..color       = accent.withOpacity(0.04)
      ..strokeWidth = 5
      ..style       = PaintingStyle.stroke;
    for (final x in [size.width * 0.22, size.width * 0.78]) {
      canvas.drawCircle(Offset(x, size.height * 0.97), 50.0 + 4 * math.sin(rotate), wheelPaint);
      canvas.drawCircle(Offset(x, size.height * 0.97), 22.0, wheelPaint);
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.progress != progress || old.rotate != rotate;
}

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5
      ..style       = PaintingStyle.stroke;
    const cols = 8, rows = 6;
    for (int i = 0; i <= cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int j = 0; j <= rows; j++) {
      final y = size.height * j / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ============================================
// HELPER WIDGETS
// ============================================

class _DarkCard extends StatelessWidget {
  final String   title;
  final IconData titleIcon;
  final Color    titleColor, accentColor;
  final Widget   child;

  const _DarkCard({
    required this.title,    required this.titleIcon,
    required this.titleColor, required this.accentColor,
    required this.child,
  });

  static const Color _card   = Color(0xFF1C1836);
  static const Color _border = Color(0xFF2D2750);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4),  blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: accentColor.withOpacity(0.1),   blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: titleColor.withOpacity(0.18), borderRadius: BorderRadius.circular(11),
                border: Border.all(color: titleColor.withOpacity(0.3)),
              ),
              child: Icon(titleIcon, color: titleColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          ]),
        ),
        Divider(height: 1, color: _border),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ]),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final IconData  icon;
  final Color     color;
  final String    label;
  final String?   value;
  final String    vocKey;
  final String?   playingKey;
  final VoidCallback? onVoc;

  const _DiagRow({
    required this.icon,   required this.color,  required this.label,
    required this.value,  required this.vocKey, required this.playingKey,
    this.onVoc,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = playingKey == vocKey;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10,
                letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (value != null && onVoc != null)
              _VocBtn(isActive: isActive, color: color, onTap: onVoc!),
          ]),
          const SizedBox(height: 5),
          value != null
              ? Text(value!, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.6))
              : Row(children: [
            SizedBox(
              width: 13, height: 13,
              child: CircularProgressIndicator(color: color.withOpacity(0.5), strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text('analyse_ia_en_cours'.tr(),
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ]),
      ),
    ]);
  }
}

class _PredRow extends StatelessWidget {
  final String    delay, msg, sev;
  final int       index;
  final String    vocKey;
  final String?   playingKey;
  final VoidCallback onVoc;

  const _PredRow({
    required this.delay, required this.msg,   required this.sev,
    required this.index, required this.vocKey, required this.playingKey,
    required this.onVoc,
  });

  @override
  Widget build(BuildContext context) {
    final bool  isActive = playingKey == vocKey;
    final Color c  = sev == 'critical' ? const Color(0xFFFF4444)
        : sev == 'warning'  ? const Color(0xFFFF8C00)
        : const Color(0xFF2979FF);
    final Color bg = sev == 'critical' ? const Color(0xFF2A0A0A)
        : sev == 'warning'  ? const Color(0xFF1F1200)
        : const Color(0xFF0A1530);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: c,
              boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          if (index < 2)
            Container(width: 2, height: 54, color: c.withOpacity(0.2)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(msg, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, height: 1.5)),
              ),
              const SizedBox(width: 8),
              Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _VocBtn(isActive: isActive, color: c, onTap: onVoc),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(0.4)),
                  ),
                  child: Text(delay, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _VocBtn extends StatelessWidget {
  final bool         isActive;
  final Color        color;
  final VoidCallback onTap;

  const _VocBtn({required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color.withOpacity(0.25) : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isActive ? color.withOpacity(0.7) : Colors.white.withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Icon(
          isActive ? Icons.pause_rounded : Icons.volume_up_rounded,
          color: isActive ? color : Colors.white.withOpacity(0.4),
          size: 15,
        ),
      ),
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
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
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
        shape: BoxShape.circle, color: widget.color,
        boxShadow: [BoxShadow(color: widget.color.withOpacity(0.7), blurRadius: 6)],
      ),
    ),
  );
}

class _AudioWaveBars extends StatefulWidget {
  final bool  isPlaying;
  final Color color;
  const _AudioWaveBars({required this.isPlaying, required this.color});

  @override
  State<_AudioWaveBars> createState() => _AudioWaveBarsState();
}

class _AudioWaveBarsState extends State<_AudioWaveBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AudioWaveBars old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying  && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.isPlaying) _c.stop();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const heights = [4.0, 14.0, 20.0, 8.0, 16.0, 6.0, 14.0, 10.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights.asMap().entries.map((e) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = widget.isPlaying
              ? (0.3 + 0.7 * ((e.key * 0.2 + _c.value) % 1.0))
              : 0.3;
          return Container(
            width: 3,
            height: 3.0 + e.value * v,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [widget.color.withOpacity(0.4), widget.color],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      )).toList(),
    );
  }
}
