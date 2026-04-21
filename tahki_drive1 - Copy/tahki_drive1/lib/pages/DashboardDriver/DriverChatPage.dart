import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverChatPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const DriverChatPage({super.key, this.onBackToDashboard});

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  final Color bluePrimary = const Color(0xFF006AD7);
  final Color blueDark = const Color(0xFF21277B);
  final Color blueLight = const Color(0xFF9AD9EA);
  final Color white = const Color(0xFFFFFFFF);
  final Color greyBlue = const Color(0xFF5F83B1);

  bool isListening = false;
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 40),
                  _buildUserMessage("Comment améliorer mon score de conduite ?"),
                  const SizedBox(height: 30),
                  _buildAuraMessage(),
                ],
              ),
            ),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Centré sans flèche
        children: [
          // Supprimé l'IconButton
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Assistant Conduite ",
                      style: GoogleFonts.poppins(color: blueDark, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bluePrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("IA",
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.edit_outlined, size: 20, color: blueDark),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bluePrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: bluePrimary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(text,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildAuraMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [bluePrimary, blueDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bluePrimary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Votre score de conduite est excellent ! Voici quelques conseils pour l'améliorer encore.",
                style: GoogleFonts.poppins(color: blueDark, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Voir mes statistiques",
                        style: GoogleFonts.poppins(color: blueDark, fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_ios, size: 12, color: blueDark),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Votre score actuel est de 85/100. Maintenez une vitesse constante et anticipez les freinages pour l'améliorer.",
                style: GoogleFonts.poppins(color: greyBlue, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1), // vertical réduit de 20 à 8
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.poppins(color: blueDark),
                decoration: InputDecoration(
                  hintText: "Posez votre question...",
                  hintStyle: GoogleFonts.poppins(color: greyBlue),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.add_circle_outline, color: bluePrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => isListening = !isListening),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: isListening ? bluePrimary : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isListening ? bluePrimary : Colors.black).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                  isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: isListening ? Colors.white : blueDark,
                  size: 28
              ),
            ),
          ),
        ],
      ),
    );
  }
}