import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';
import 'internal_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final bool isStaff;

  const ChatListScreen({super.key, required this.isStaff});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiService();
  List<dynamic> _allContacts = [];
  List<dynamic> _filteredContacts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    
    // Подписка на уведомления о новых сообщениях для мгновенного обновления списка
    _chatSubscription = PushNotificationService.chatMessageStream.stream.listen((_) {
      _fetchContacts();
    });
  }

  StreamSubscription? _chatSubscription;

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    final contacts = await _api.getChatContacts(isStaff: widget.isStaff);
    if (mounted) {
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts = _allContacts.where((c) {
          final name = (c['contact_name'] ?? '').toString().toLowerCase();
          final phone = (c['contact_phone'] ?? '').toString().toLowerCase();
          return name.contains(q) || phone.contains(q);
        }).toList();

        _filteredContacts.sort((a, b) {
          final nameA = (a['contact_name'] ?? '').toString();
          final nameB = (b['contact_name'] ?? '').toString();
          return nameA.compareTo(nameB);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: pal.bg,
      body: Column(
        children: [
          // Синий заголовок как в Офисе
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Сообщения',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _fetchContacts,
                    ),
                  ],
                ),
                // Поиск только для сотрудников
                if (widget.isStaff) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Поиск сотрудника или клиента...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black45),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: pal.textHint),
                            const SizedBox(height: 16),
                            Text(
                              widget.isStaff ? 'Ничего не найдено' : 'Нет доступных сотрудников',
                              style: TextStyle(color: pal.textSec),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final contactEntityType = contact['entity_type'] ?? '';
                          
                          // Если мы клиент, показываем только STAFF и OFFICE
                          if (!widget.isStaff && contactEntityType == 'CLIENT') {
                            return const SizedBox.shrink();
                          }

                          final isStaffContact = contactEntityType != 'CLIENT';
                          final color = isStaffContact ? const Color(0xFF2563EB) : const Color(0xFFEC4899);

                          return InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InternalChatScreen(
                                  isStaff: widget.isStaff,
                                  contactId: contact['contact_id'].toString(),
                                  contactName: contact['contact_name'],
                                  entityType: contactEntityType,
                                ),
                              ),
                            ).then((_) => _fetchContacts()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: pal.border, width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: color.withOpacity(0.1),
                                    child: Icon(
                                      isStaffContact ? Icons.person_outline : Icons.person,
                                      color: color,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                contact['contact_name'] ?? 'Без имени',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: pal.textPri,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (contact['last_message_date'] != null)
                                              Text(
                                                _formatTime(contact['last_message_date']),
                                                style: TextStyle(color: pal.textHint, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                contact['last_message'] ?? (isStaffContact ? 'Сотрудник' : 'Клиент'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: contact['last_message'] != null ? pal.textSec : pal.textHint,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (contact['unread_count'] != null && int.parse(contact['unread_count'].toString()) > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  contact['unread_count'].toString(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
