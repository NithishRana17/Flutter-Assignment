import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/logbook_entry.dart';
import '../../../providers/providers.dart';

/// Captain MAVE AI Assistant Screen
class CaptainMaveScreen extends ConsumerStatefulWidget {
  final LogbookEntry? contextFlight;

  const CaptainMaveScreen({super.key, this.contextFlight});

  @override
  ConsumerState<CaptainMaveScreen> createState() => _CaptainMaveScreenState();
}

class _CaptainMaveScreenState extends ConsumerState<CaptainMaveScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(_ChatMessage(
      isUser: false,
      message: "Hello! I'm Captain MAVE, your AI flight instructor assistant. 🛫\n\n"
          "I can help you with:\n"
          "• Flight analysis and advice\n"
          "• Safety tips\n"
          "• Training suggestions\n"
          "• Aviation questions\n\n"
          "How can I help you today?",
    ));

    // If we have a context flight, offer to analyze it
    if (widget.contextFlight != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _analyzeCurrentFlight();
        }
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _analyzeCurrentFlight() async {
    if (widget.contextFlight == null) return;

    setState(() {
      _isLoading = true;
      _messages.add(_ChatMessage(
        isUser: true,
        message: "Analyze my flight: ${widget.contextFlight!.depIcao} → ${widget.contextFlight!.arrIcao}",
      ));
    });

    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.generateFlightAdvice(widget.contextFlight!);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          isUser: false,
          message: response.message,
          isError: !response.success,
        ));
      });
    }
  }

  void _sendMessage() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    _questionController.clear();

    setState(() {
      _isLoading = true;
      _messages.add(_ChatMessage(isUser: true, message: question));
    });

    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.askCaptainMave(
      question,
      contextFlight: widget.contextFlight,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          isUser: false,
          message: response.message,
          isError: !response.success,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gemini = ref.read(geminiServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flight, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Captain MAVE', style: TextStyle(fontSize: 16)),
                Text(
                  'AI Flight Assistant',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!gemini.isConfigured)
            IconButton(
              icon: const Icon(Icons.warning_amber, color: Colors.orange),
              onPressed: () => _showApiKeyWarning(),
              tooltip: 'API Key Required',
            ),
        ],
      ),
      body: Column(
        children: [
          // Flight context banner
          if (widget.contextFlight != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discussing: ${widget.contextFlight!.depIcao} → ${widget.contextFlight!.arrIcao} • ${widget.contextFlight!.aircraftReg}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index], index);
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Ask Captain MAVE...',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading && gemini.isConfigured,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _isLoading || !gemini.isConfigured
                        ? AppColors.textMuted
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _isLoading || !gemini.isConfigured ? null : _sendMessage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.send,
                          color: _isLoading ? AppColors.textSecondary : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.flight, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.primary
                    : message.isError
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isError
                    ? Border.all(color: AppColors.error.withOpacity(0.3))
                    : null,
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : message.isError
                          ? AppColors.error
                          : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.textMuted,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.flight, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(100),
                const SizedBox(width: 4),
                _buildDot(200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scaleXY(begin: 0.5, end: 1.0, duration: 400.ms, delay: Duration(milliseconds: delayMs))
        .then()
        .scaleXY(begin: 1.0, end: 0.5, duration: 400.ms)
        .slideY(begin: 0, end: -0.3, duration: 400.ms, delay: Duration(milliseconds: delayMs))
        .then()
        .slideY(begin: -0.3, end: 0, duration: 400.ms);
  }

  void _showApiKeyWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.orange),
            SizedBox(width: 8),
            Text('API Key Required'),
          ],
        ),
        content: const Text(
          'To use Captain MAVE, you need to add your Gemini API key.\n\n'
          'Open:\nlib/core/constants/app_constants.dart\n\n'
          'and update:\nGeminiConfig.apiKey',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String message;
  final bool isError;

  _ChatMessage({
    required this.isUser,
    required this.message,
    this.isError = false,
  });
}
