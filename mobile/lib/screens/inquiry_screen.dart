import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  // Дополнительные контроллеры для заявки на кредит
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  final _dateController = TextEditingController();

  String _selectedType = 'GENERAL';
  bool _isSubmitting = false;
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  final Map<String, String> _types = {
    'GENERAL': 'Общий вопрос',
    'LOAN_APP': 'Заявка на кредит',
    'SUPPORT': 'Техподдержка',
    'COMPLAINT': 'Жалоба',
  };

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await ApiService().getInquiries();
      if (mounted) {
        setState(() {
          _history = data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String finalMessage = _messageController.text;
    
    // Если это заявка на кредит, формируем расширенное сообщение
    if (_selectedType == 'LOAN_APP') {
      finalMessage = """
ЗАЯВКА НА КРЕДИТ
----------------
Сумма: ${_amountController.text}
Цель: ${_purposeController.text}
Желаемая дата: ${_dateController.text}
Комментарий: ${_messageController.text}
""".trim();
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().sendInquiry(_selectedType, finalMessage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обращение успешно отправлено')),
        );
        _messageController.clear();
        _amountController.clear();
        _purposeController.clear();
        _dateController.clear();
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Связаться с офисом'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildForm(),
              const SizedBox(height: 40),
              const Text(
                'История обращений',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            dropdownColor: Colors.white,
            decoration: const InputDecoration(
              labelText: 'Выберите тему',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            items: _types.entries.map((e) {
              return DropdownMenuItem(value: e.key, child: Text(e.value));
            }).toList(),
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          
          const SizedBox(height: 20),

          // Дополнительные поля для заявки на кредит
          if (_selectedType == 'LOAN_APP') ...[
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Желаемая сумма',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Укажите сумму' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purposeController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Цель кредита',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Укажите цель' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Желаемая дата получения',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Выберите дату' : null,
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _messageController,
            maxLines: 4,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: _selectedType == 'LOAN_APP' ? 'Дополнительный комментарий' : 'Ваше сообщение',
              labelStyle: const TextStyle(color: Colors.grey),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              alignLabelWithHint: true,
            ),
            validator: (val) {
              if (_selectedType != 'LOAN_APP' && (val == null || val.length < 5)) {
                return 'Минимум 5 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF2E5BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Отправить',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'У вас пока нет обращений',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _history.map((item) {
        final hasReply = item['reply_message'] != null;
        final status = item['status'] == 'CLOSED' ? 'Отвечено' : 'В обработке';
        final statusColor = item['status'] == 'CLOSED' ? Colors.green : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _types[item['type']] ?? item['type'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['message'],
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd.MM.yyyy HH:mm')
                    .format(DateTime.parse(item['created_at'])),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              if (hasReply) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                const Text(
                  'Ответ офиса:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5BFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['reply_message'],
                  style: const TextStyle(
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm')
                      .format(DateTime.parse(item['replied_at'])),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
