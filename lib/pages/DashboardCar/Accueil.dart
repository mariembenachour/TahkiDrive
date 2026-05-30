import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tahki_drive1/pages/Auth/LoginPage.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  final double _dragThreshold = 250.0;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      if (_dragOffset < 0) _dragOffset = 0;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    double screenHeight = MediaQuery.of(context).size.height;

    if (_dragOffset >= _dragThreshold) {
      setState(() {
        _dragOffset = screenHeight;
      });

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      ).then((_) {
        // Reset drag when coming back
        setState(() {
          _dragOffset = 0;
        });
      });
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double opacity = (1 - (_dragOffset / _dragThreshold)).clamp(0.0, 1.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7226FF),
              Color(0xFF160078),
              Color(0xFF010030),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Stack(
              children: [
                // Welcome page qui slide vers le bas
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  top: _dragOffset,
                  left: 0,
                  right: 0,
                  bottom: -_dragOffset,
                  child: Opacity(
                    opacity: opacity,
                    child: _buildWelcomePage(screenHeight),
                  ),
                ),

                // Swipe hint
                if (opacity > 0)
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:  [
                            Text(
                              "Glissez vers le bas pour vous connecter",
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            SizedBox(height: 8.h),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 40.w,
                              color: Color(0xFF7226FF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(double screenHeight) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        color: const Color(0xFFFBF7FF),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Purple header arc
            Container(
              height: 300.h,
              decoration:  BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7226FF),
                    Color(0xFF160078),
                    Color(0xFF010030),
                  ],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(175.r)),
              ),
              child: Center(
                child: Text(
                  'Bienvenue sur TahkiDrive',
                  style: GoogleFonts.orbitron(
                    fontSize: 23.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Car image
            Positioned(
              top: 170,
              left: 35,
              right: 35,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: screenHeight * 0.4,
                      width: screenHeight * 0.2,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(100.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 50,
                            spreadRadius: 35,
                            offset: const Offset(0, 40),
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'images/porshe_top_view.png',
                      height: screenHeight * 0.65,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
