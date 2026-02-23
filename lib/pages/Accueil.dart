import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  final double _dragThreshold = 250.0;

  bool _showLoginAnimations = false; // <-- Flag pour déclencher les animations après le glissement

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

    _controller.forward(); // Animation d'ouverture du welcome screen
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
        _showLoginAnimations = true; // <-- Déclenche animation login
      });
    } else {
      setState(() {
        _dragOffset = 0;
        _showLoginAnimations = false;
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
                _buildLoginPage(screenHeight),
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
            Container(
              height: 300,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7226FF),
                    Color(0xFF160078),
                    Color(0xFF010030),
                  ],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(175)),
              ),
              child: Center(
                child: Text(
                  'Welcome to TahkiDrive',
                  style: GoogleFonts.orbitron(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 170,
              left: 35,
              right: 35,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shadow sous la voiture
                    Container(
                      height: screenHeight * 0.4,
                      width: screenHeight * 0.2,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
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
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: const [
                  Text(
                    "Slide down to Login",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Icon(Icons.keyboard_arrow_down, size: 40, color: Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPage(double screenHeight) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'images/bg cars.jpg',
          fit: BoxFit.cover,
        ),

        // Overlay sombre pour rendre le fond plus “dark”
        Container(
          color: Colors.black.withOpacity(0.4), // ajuste ici pour plus ou moins sombre
        ),

        // Gradient pour lisibilité du texte
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),

        // Contenu du login
        SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            height: screenHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Titre animé
                _buildAnimatedTitle(),
                const SizedBox(height: 50),

                // Champs animés
                _buildAnimatedTextField("Login", Icons.email),
                const SizedBox(height: 20),
                _buildAnimatedTextField("Password", Icons.lock, obscure: true),
                const SizedBox(height: 40),

                // Bouton animé
// Dans la méthode _buildLoginPage, modifie l'appel du bouton :
                _buildAnimatedButton(() {

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  );
                }),              ],
            ),
          ),
        ),
      ],
    );
  }


  // -------------------- Animated Title --------------------
  Widget _buildAnimatedTitle() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _showLoginAnimations ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 600),
        offset: _showLoginAnimations ? Offset.zero : const Offset(0, -0.5),
        curve: Curves.easeOutBack,
        child: Text(
          'Tahki Drive',
          style: GoogleFonts.orbitron(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // -------------------- Animated TextField --------------------
  Widget _buildAnimatedTextField(String hint, IconData icon, {bool obscure = false}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _showLoginAnimations ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 800),
        offset: _showLoginAnimations ? Offset.zero : const Offset(0, 0.5),
        curve: Curves.easeOutBack,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.withOpacity(0.25),
                Colors.purpleAccent.withOpacity(0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.35),
                offset: const Offset(0, 10),
                blurRadius: 20,
              ),
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.2),
                offset: const Offset(-5, -5),
                blurRadius: 15,
              ),
            ],
          ),
          child: TextField(
            obscureText: obscure,
            style: GoogleFonts.poppins(color: Colors.white),
            cursorColor: Colors.white, // curseur blanc
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white), // icône blanche
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.white70), // hint blanc semi-transparent
              filled: true,
              fillColor: const Color(0xFF160078).withOpacity(0.25), // fond violet foncé transparent
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFF7226FF), width: 2), // bordure violet clair
              ),
            ),
          ),

        ),
      ),
    );
  }

  // -------------------- Animated Button --------------------
  Widget _buildAnimatedButton(VoidCallback onPressed) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _showLoginAnimations ? 1 : 0,
      child: AnimatedScale(
        scale: _showLoginAnimations ? 1 : 0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7226FF), // violet clair
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            shadowColor: const Color(0xFF160078), // violet foncé
            elevation: 12,
          ),
          child: Text(
            'Log in',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),

      ),
    );
  }
}