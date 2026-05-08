import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';

class InternalChatScreen extends StatefulWidget {
  final bool isStaff;
  final String contactId;
  final String contactName;
  final String entityType;

  const InternalChatScreen({
    super.key,
    required this.isStaff,
    required this.contactId,
    required this.contactName,
    required this.entityType,
  });

  @override
  State<InternalChatScreen> createState() => _InternalChatScreenState();
}

class _InternalChatScreenState extends State<InternalChatScreen> {
  final _api = ApiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    
    // Мгновенное обновление сообщений при получении Пуша от этого контакта
    _chatSubscription = PushNotificationService.chatMessageStream.stream.listen((data) {
      if (data['sender_id'] == widget.contactId) {
        _fetchMessages(silent: true);
      }
    });
  }

  StreamSubscription? _chatSubscription;

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final messages = await _api.getChatHistory(
        isStaff: widget.isStaff,
        receiverId: widget.contactId,
        receiverType: widget.entityType,
      );
      if (mounted) {
        // Сортируем: новые в начале (потому что ListView.reverse=true)
        final List<dynamic> sorted = List.from(messages);
        sorted.sort((a, b) => b['created_at'].compareTo(a['created_at']));
        
        final hasNewMessages = sorted.length > _messages.length;

        setState(() {
          _messages = sorted;
          _isLoading = false;
        });
        
        // При ListView(reverse: true) 0 - это низ. Скролл не нужен, 
        // но если мы добавили свое сообщение, убедимся что мы внизу.
        if (hasNewMessages && !silent) _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // При reverse: true низ - это 0
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    
    // Оптимистичное добавление в начало списка
    final tempMessage = {
      'message_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_type': widget.isStaff ? 'STAFF' : 'CLIENT',
      'message_text': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _messages.insert(0, tempMessage);
      _textController.clear();
    });
    _scrollToBottom();

    try {
      await _api.sendChatMessage(
        text,
        isStaff: widget.isStaff,
        receiverId: widget.contactId,
        receiverType: widget.entityType,
      );
      await _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка отправки сообщения'), backgroundColor: Colors.red),
        );
        setState(() {
          _messages.removeWhere((m) => m['message_id'] == tempMessage['message_id']);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    
    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.card,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.contactName,
          style: TextStyle(color: pal.textPri, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('Нет сообщений', style: TextStyle(color: pal.textSec)))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMine = msg['sender_type'] == (widget.isStaff ? 'STAFF' : 'CLIENT');
                          
                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                color: isMine ? pal.accent : pal.card,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
                                  bottomLeft: !isMine ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                                border: isMine ? null : Border.all(color: pal.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['message_text'] ?? '',
                                    style: TextStyle(
                                      color: isMine ? Colors.white : pal.textPri,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg['created_at']),
                                    style: TextStyle(
                                      color: isMine ? Colors.white70 : pal.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Ввод сообщения
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.card,
              border: Border(top: BorderSide(color: pal.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: pal.textPri),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение...',
                        hintStyle: TextStyle(color: pal.textHint),
                        filled: true,
                        fillColor: pal.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: pal.accent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
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

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final d = DateTime.parse(isoDate).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
