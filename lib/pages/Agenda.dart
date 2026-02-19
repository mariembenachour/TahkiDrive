import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage>
    with SingleTickerProviderStateMixin {

  // ================= ANIMATION =================
  late AnimationController _controller;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================= LUXURY ENTRY =================
  Widget _luxuryAnimatedEntry({
    required Widget child,
    required double delay,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        1,
        curve: Curves.easeOutBack,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.92,
            end: 1,
          ).animate(animation),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4904BD), Color(0xFFF0EDF6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // ================= HEADER =================
              _luxuryAnimatedEntry(
                delay: 0.05,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderButton(
                        Icons.arrow_back_ios_new,
                            () => Navigator.pop(context),
                      ),
                      const Text(
                        "Maintenance Calendar",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      _buildHeaderButton(
                        Icons.add,
                            () {},
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
              ),

              // ================= CONTENT =================
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ================= CALENDAR =================
                        _luxuryAnimatedEntry(
                          delay: 0.2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TableCalendar(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF160078),
                                ),
                                leftChevronIcon: Icon(Icons.chevron_left,
                                    color: Color(0xFF7226FF)),
                                rightChevronIcon: Icon(Icons.chevron_right,
                                    color: Color(0xFF7226FF)),
                              ),
                              calendarStyle: const CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: Color(0xFFD1B3FF),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: Color(0xFF7226FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        _luxuryAnimatedEntry(
                          delay: 0.35,
                          child: const Text(
                            "Upcoming",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF160078),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        _luxuryAnimatedEntry(
                          delay: 0.45,
                          child: _buildMaintenanceItem(
                            title: "Annual Inspection",
                            date: "Aug 11, 2025 • 9:00 AM",
                            location: "Elite Auto Service",
                            icon: Icons.assignment_outlined,
                            tag: "Overdue",
                            tagColor: Colors.redAccent,
                          ),
                        ),

                        _luxuryAnimatedEntry(
                          delay: 0.6,
                          child: _buildMaintenanceItem(
                            title: "Oil Change",
                            date: "Aug 18, 2025 • 10:00 AM",
                            location: "Elite Auto Service",
                            icon: Icons.oil_barrel_outlined,
                            showButton: true,
                          ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER BUTTON =================
  Widget _buildHeaderButton(
      IconData icon, VoidCallback onTap,
      {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF160078) // 🔥 violet foncé
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // ================= MAINTENANCE ITEM =================
  Widget _buildMaintenanceItem({
    required String title,
    required String date,
    required String location,
    required IconData icon,
    String? tag,
    Color? tagColor,
    bool showButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7226FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon,
                color: const Color(0xFF7226FF), size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (tag != null)
                      Text(tag,
                          style: TextStyle(
                            color: tagColor ?? Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                  ],
                ),
                Text(date,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13)),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location,
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showButton)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF160078)), // 🔥 violet foncé
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                "View Details",
                style: TextStyle(
                  color: Color(0xFF160078), // 🔥 violet foncé
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
