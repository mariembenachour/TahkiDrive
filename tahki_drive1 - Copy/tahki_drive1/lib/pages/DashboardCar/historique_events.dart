// pages/historique_events.dart
import 'package:flutter/material.dart';
import 'package:tahki_drive1/services/notification_service.dart';

class HistoriqueEventsPage extends StatefulWidget {
  final int driverId;

  const HistoriqueEventsPage({required this.driverId, super.key});

  @override
  State<HistoriqueEventsPage> createState() => _HistoriqueEventsPageState();
}

class _HistoriqueEventsPageState extends State<HistoriqueEventsPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _events = [];
  bool _isLoading = true;
  bool _showOnlyNew = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Gradient _gradient = const LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _loadEvents();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await NotificationService.fetchAllEvents(widget.driverId);
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  Future<void> _markAsNotified(int eventId) async {
    await NotificationService.markEventAsNotified(eventId, widget.driverId);
    setState(() {
      final index = _events.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        _events[index]['is_notified'] = '1';
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Alerte marquée comme lue'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedEvents = _showOnlyNew
        ? _events.where((e) => e['is_notified'] == '0' || e['is_notified'] == false).toList()
        : _events;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // ========== FLÈCHE DE RETOUR BLEANCHE AJOUTÉE ==========
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Aujourd'hui",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _gradient,
          ),
        ),
        actions: [
          // Filtre animé
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _showOnlyNew ? Icons.notifications_active : Icons.notifications_none,
                        key: ValueKey(_showOnlyNew),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showOnlyNew = !_showOnlyNew;
                      });
                    },
                    tooltip: _showOnlyNew ? 'Voir tout' : 'Voir uniquement les nouveaux',
                  ),
                ),
              );
            },
          ),
          // Rafraîchir
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                  onPressed: _loadEvents,
                  tooltip: 'Rafraîchir',
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Colors.white, Color(0xFFF1F5F9)],
          ),
        ),
        child: _isLoading
            ? Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const CircularProgressIndicator(
                  color: Color(0xFF7C3AED),
                  strokeWidth: 3,
                ),
              );
            },
          ),
        )
            : displayedEvents.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.only(top: 120, left: 16, right: 16, bottom: 30),
          itemCount: displayedEvents.length,
          itemBuilder: (context, index) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1 * (index + 1)),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(0.05 * index, 1, curve: Curves.easeOutQuint),
                )),
                child: _buildEventCard(displayedEvents[index], index),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF7C3AED).withOpacity(0.1), const Color(0xFF4F46E5).withOpacity(0.05)],
                      ),
                    ),
                    child: Icon(
                      _showOnlyNew ? Icons.notifications_off_outlined : Icons.history_outlined,
                      size: 60,
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _showOnlyNew ? 'Aucune nouvelle alerte' : 'Aucun historique',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showOnlyNew
                        ? 'Toutes les alertes sont déjà lues'
                        : 'Aucun événement pour le moment',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, int index) {
    final isPanne = event['doc_type'] == null;
    final isNew = event['is_notified'] == '0' || event['is_notified'] == false;

    final Color mainColor = isPanne ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final Color darkColor = isPanne ? const Color(0xFFB91C1C) : const Color(0xFF1D4ED8);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isNew) {
                      _markAsNotified(event['id']);
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isNew ? mainColor.withOpacity(0.3) : Colors.grey.shade100,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [mainColor, darkColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPanne ? Icons.warning_rounded : Icons.description_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event['title'] ?? (isPanne ? 'Alerte' : 'Document'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNew)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [mainColor, darkColor],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                event['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(event['date']),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                  if (event['mark'] != null) ...[
                                    const SizedBox(width: 16),
                                    Icon(Icons.directions_car_rounded, size: 12, color: Colors.grey.shade400),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${event['mark']} ${event['model']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final eventDate = DateTime(date.year, date.month, date.day);

      String dayFormat;
      if (eventDate == today) {
        dayFormat = "Aujourd'hui";
      } else if (eventDate == yesterday) {
        dayFormat = "Hier";
      } else {
        dayFormat = '${date.day}/${date.month}/${date.year}';
      }

      return '$dayFormat à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}