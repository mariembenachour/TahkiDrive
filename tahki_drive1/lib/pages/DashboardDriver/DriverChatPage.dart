import 'package:flutter/material.dart';

class DriverChatPage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const DriverChatPage({super.key, this.onBackToDashboard});

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<ChatContact> _contacts = [
    ChatContact(name: "Support Technique", lastMessage: "Comment puis-je vous aider ?", time: "14:30", unread: 2, avatar: Icons.support_agent, isOnline: true),
    ChatContact(name: "Centre de Contrôle", lastMessage: "Trajet confirmé", time: "11:15", unread: 0, avatar: Icons.location_on, isOnline: true),
    ChatContact(name: "Marc (Chauffeur)", lastMessage: "Merci pour l'info", time: "Hier", unread: 0, avatar: Icons.person, isOnline: false),
    ChatContact(name: "Dépôt Lyon", lastMessage: "Véhicule prêt", time: "Hier", unread: 0, avatar: Icons.garage, isOnline: true),
  ];

  bool _isChatOpen = false;
  ChatContact? _selectedContact;
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    // Messages de démo
    _messages.addAll([
      ChatMessage(text: "Bonjour, j'ai un problème avec le véhicule", isMe: true, time: "14:25"),
      ChatMessage(text: "Bonjour, quel est le problème exactement ?", isMe: false, time: "14:26"),
      ChatMessage(text: "Le voyant moteur est allumé", isMe: true, time: "14:27"),
    ]);
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          text: _messageController.text,
          isMe: true,
          time: TimeOfDay.now().format(context),
        ));
        _messageController.clear();
      });
      // Simuler réponse
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              text: "Merci pour votre message. Un agent va vous répondre dans quelques instants.",
              isMe: false,
              time: TimeOfDay.now().format(context),
            ));
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF006AD7), // Bleu foncé
              Color(0xFF9AD9EA), // Bleu clair
              Color(0xFF21277B), // Bleu nuit
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isChatOpen && _selectedContact != null
                    ? _buildChatConversation()
                    : _buildContactsList(),
              ),
              if (_isChatOpen) _buildInputSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_isChatOpen) {
                setState(() {
                  _isChatOpen = false;
                  _selectedContact = null;
                });
              } else if (widget.onBackToDashboard != null) {
                widget.onBackToDashboard!();
              }
            },
          ),
          Text(
            _isChatOpen ? _selectedContact!.name : "Messages",
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedContact = contact;
              _isChatOpen = true;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(contact.avatar, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(contact.lastMessage, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                if (contact.unread > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(contact.unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatConversation() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[_messages.length - 1 - index];
              return _buildMessageBubble(message);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blueAccent : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: message.isMe ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(message.time, style: TextStyle(color: message.isMe ? Colors.white70 : Colors.black54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Écrire un message...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              height: 50,
              width: 50,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  ChatMessage({required this.text, required this.isMe, required this.time});
}

class ChatContact {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final IconData avatar;
  final bool isOnline;
  ChatContact({required this.name, required this.lastMessage, required this.time, required this.unread, required this.avatar, required this.isOnline});
}