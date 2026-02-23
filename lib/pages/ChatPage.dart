import 'package:flutter/material.dart';

// On transforme AuraApp en un simple Widget (Stateless) sans MaterialApp
class AuraApp extends StatelessWidget {
  final VoidCallback? onBackToDashboard; // Callback pour le retour

  const AuraApp({super.key, this.onBackToDashboard});

  @override
  Widget build(BuildContext context) {
    // On retourne directement ChatPage
    return ChatPage(onBackToDashboard: onBackToDashboard);
  }
}

class ChatPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const ChatPage({super.key, this.onBackToDashboard});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool isListening = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF893DEF),
              Color(0xFFD6CEE4),
              Color(0xFF5C3897),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 40),
                    _buildUserMessage("can you change my training\nschedule?"),
                    const SizedBox(height: 30),
                    _buildAuraMessage(),
                  ],
                ),
              ),
              _buildInputSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // 👇 CORRECTION ICI : On utilise le callback
              if (widget.onBackToDashboard != null) {
                widget.onBackToDashboard!();
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Text("Aura 1.3 ", style: TextStyle(color: Colors.white)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("BETA", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ... (Garde tes widgets _buildUserMessage, _buildAuraMessage et _buildInputSection identiques)

  Widget _buildUserMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Colors.cyan, Colors.purple, Colors.pink, Colors.cyan]),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Yes, of course. We're discussing training in another chat.",
                style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
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
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Training", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white70),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "If you follow the link, we'll continue in the other chat.",
                style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 65),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 55,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter Message",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.add_circle_outline, color: Colors.white),
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
                color: isListening ? Colors.purpleAccent : Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
                boxShadow: isListening ? [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 15)] : [],
              ),
              child: Icon(isListening ? Icons.mic : Icons.mic_none_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}