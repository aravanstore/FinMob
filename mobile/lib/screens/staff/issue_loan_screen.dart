import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class IssueLoanScreen extends StatefulWidget {
  const IssueLoanScreen({super.key});

  @override
  State<IssueLoanScreen> createState() => _IssueLoanScreenState();
}

class _IssueLoanScreenState extends State<IssueLoanScreen> {
  int _currentStep = 0;

  // Данные клиента
  List<dynamic> _clientResults = [];
  Map<String, dynamic>? _selectedClient;
  bool _isSearching = false;

  // Параметры займа
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _termCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _collateralDescCtrl = TextEditingController();
  final _collateralValueCtrl = TextEditingController();
  final _feesPercentCtrl = TextEditingController(text: '0');

  String _repaymentType = 'Аннуитетный (Стандартный)';
  String _nbkrCategory = 'Прочие';
  DateTime _issueDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    _purposeCtrl.dispose();
    _collateralDescCtrl.dispose();
    _collateralValueCtrl.dispose();
    _feesPercentCtrl.dispose();
    super.dispose();
  }

  void _searchClients(String q) async {
    if (q.length < 2) {
      setState(() => _clientResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.searchClients(q);
      if (mounted) setState(() => _clientResults = res);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _submitLoan() async {
    if (_selectedClient == null ||
        _amountCtrl.text.isEmpty ||
        _rateCtrl.text.isEmpty ||
        _termCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните все обязательные поля')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = context.read<ApiService>();
      await api.createLoan({
        'client_id': _selectedClient!['client_id'],
        'loan_amount': double.tryParse(_amountCtrl.text) ?? 0,
        'interest_rate_annual': double.tryParse(_rateCtrl.text) ?? 0,
        'term_months': int.tryParse(_termCtrl.text) ?? 1,
        'repayment_type': _repaymentType,
        'issue_date': _issueDate.toIso8601String().split('T')[0],
        'nbkr_category': _nbkrCategory,
        'purpose': _purposeCtrl.text,
        'collateral_description': _collateralDescCtrl.text,
        'collateral_value': double.tryParse(_collateralValueCtrl.text) ?? 0,
        'fees_percent': double.tryParse(_feesPercentCtrl.text) ?? 0,
      });
      if (!mounted) return;
      context.pop();
      return;
    } on DioException catch (e) {
      String msg = 'Ошибка сервера. Попробуйте позже.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = 'Нет связи с сервером. Проверьте интернет.';
      } else if (e.response?.data is Map && e.response!.data['error'] != null) {
        msg = e.response!.data['error'].toString();
      } else if (e.response?.statusCode == 500) {
        msg = 'Ошибка на сервере. Обратитесь к администратору.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        title: const Text('Оформление займа'),
        backgroundColor: pal.surface,
        foregroundColor: pal.textPri,
        elevation: 0,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _selectedClient == null) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Сначала выберите клиента')));
            return;
          }
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submitLoan();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            context.pop();
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastStep ? Colors.green : pal.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isLastStep ? 'Оформить' : 'Далее',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: pal.border),
                      ),
                      onPressed: _isSubmitting ? null : details.onStepCancel,
                      child:
                          Text('Назад', style: TextStyle(color: pal.textPri)),
                    ),
                  ),
                ]
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text('Выбор клиента',
                style:
                    TextStyle(color: pal.textPri, fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 0,
            state: _selectedClient != null
                ? StepState.complete
                : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedClient != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          pal.accent.withOpacity(0.2),
                          pal.accent.withOpacity(0.05)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _selectedClient!['photo_base64'] != null 
                                ? () => _showFullScreenPhoto(context, _selectedClient!['photo_base64']) 
                                : null,
                              child: Hero(
                                tag: 'client_photo_hero',
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: pal.accent,
                                    borderRadius: BorderRadius.circular(12),
                                    image: _selectedClient!['photo_base64'] != null 
                                      ? DecorationImage(
                                          image: MemoryImage(base64Decode(_selectedClient!['photo_base64'])),
                                          fit: BoxFit.cover,
                                        ) 
                                      : null,
                                  ),
                                  child: _selectedClient!['photo_base64'] == null 
                                    ? const Icon(Icons.person, color: Colors.white, size: 30) 
                                    : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _selectedClient!['full_name'] ??
                                          _selectedClient!['legal_name'] ??
                                          'Без имени',
                                      style: TextStyle(
                                          color: pal.textPri,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text('ИНН: ${_selectedClient!['inn'] ?? '-'}',
                                      style: TextStyle(
                                          color: pal.textSec, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _selectedClient = null),
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Выбрать другого'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: pal.accent,
                              side: BorderSide(color: pal.accent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showClientPicker(context, pal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pal.surface,
                        foregroundColor: pal.textPri,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 30, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: pal.border, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 48, color: pal.accent),
                          const SizedBox(height: 12),
                          Text('Нажмите, чтобы выбрать клиента',
                              style: TextStyle(
                                  color: pal.textPri,
                                  fontWeight: FontWeight.bold)),
                          Text('Поиск по ФИО или ИНН',
                              style:
                                  TextStyle(color: pal.textSec, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Step(
            title: Text('Параметры займа',
                style:
                    TextStyle(color: pal.textPri, fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                _buildField(pal, 'Сумма займа (сом)', _amountCtrl,
                    TextInputType.number),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildField(pal, 'Ставка (% год)', _rateCtrl,
                            TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildField(pal, 'Срок (мес)', _termCtrl,
                            TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(pal, 'Комиссия (%)', _feesPercentCtrl,
                    TextInputType.number),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тип погашения',
                        style: TextStyle(color: pal.textSec, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: pal.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: pal.surface,
                          value: _repaymentType,
                          items: [
                            'Аннуитетный (Стандартный)',
                            'Только проценты (в конце ОД)',
                            'Равными долями ОД',
                            'Гибкий (по периодам)',
                          ]
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: TextStyle(color: pal.textPri))))
                              .toList(),
                          onChanged: (v) => setState(() => _repaymentType = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Категория НБКР',
                        style: TextStyle(color: pal.textSec, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: pal.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: pal.surface,
                          value: _nbkrCategory,
                          items: [
                            'Промышленность',
                            'Сельское хозяйство',
                            'Торговля и комерция',
                            'Услуги',
                            'Транспорт',
                            'Строительство',
                            'Потребительские',
                            'Прочие',
                          ]
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: TextStyle(color: pal.textPri))))
                              .toList(),
                          onChanged: (v) => setState(() => _nbkrCategory = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(pal, 'Детальная цель (для договора)', _purposeCtrl,
                    TextInputType.text),
                const SizedBox(height: 16),
                _buildField(pal, 'Описание залога', _collateralDescCtrl,
                    TextInputType.text),
                const SizedBox(height: 16),
                _buildField(pal, 'Оценочная стоимость залога',
                    _collateralValueCtrl, TextInputType.number),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Дата выдачи',
                        style: TextStyle(color: pal.textSec, fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _issueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: pal.accent,
                                  onPrimary: Colors.white,
                                  surface: pal.surface,
                                  onSurface: pal.textPri,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null && mounted)
                          setState(() => _issueDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: pal.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${_issueDate.day.toString().padLeft(2, '0')}.${_issueDate.month.toString().padLeft(2, '0')}.${_issueDate.year}",
                              style:
                                  TextStyle(color: pal.textPri, fontSize: 16),
                            ),
                            Icon(Icons.calendar_month, color: pal.textSec),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: Text('Подтверждение',
                style:
                    TextStyle(color: pal.textPri, fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 2,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                      label: 'Клиент:',
                      value: _selectedClient?['full_name'] ??
                          _selectedClient?['legal_name'] ??
                          '-',
                      pal: pal),
                  const Divider(),
                  _SummaryRow(
                      label: 'Сумма:',
                      value: '${_amountCtrl.text} сом',
                      pal: pal),
                  const Divider(),
                  _SummaryRow(
                      label: 'Срок:',
                      value: '${_termCtrl.text} мес.',
                      pal: pal),
                  const Divider(),
                  _SummaryRow(
                      label: 'Ставка:', value: '${_rateCtrl.text}%', pal: pal),
                  const Divider(),
                  _SummaryRow(
                      label: 'Погашение:', value: _repaymentType, pal: pal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIX: вместо StatefulBuilder внутри showDialog используем отдельный StatefulWidget.
  // Это исправляет ошибку "_dependents.isEmpty is not true" (красный экран Flutter).
  //
  // ПРИЧИНА БАГА: StatefulBuilder не имеет initState(), поэтому загрузку данных
  // запускали через if(isLoading) прямо в build(). Это вызывало Future.microtask()
  // при каждом ребилде и setDialogState() на уже закрытом (мёртвом) диалоге.
  // Итог: assert _dependents.isEmpty fails → красный экран → Android ANR.
  Future<void> _showClientPicker(
      BuildContext outerContext, AppPalette pal) async {
    final api = outerContext.read<ApiService>();

    final selected = await showDialog<Map<String, dynamic>>(
      context: outerContext,
      barrierDismissible: true,
      builder: (_) => _ClientPickerDialog(api: api, pal: pal),
    );

    if (selected != null && mounted) {
      setState(() => _selectedClient = selected);
      
      // Асинхронно подгружаем фото и другие детали
      try {
        final fullDetails = await api.getClientDetails(selected['client_id'].toString());
        if (mounted) {
          // ВАЖНО: берем объект 'client' из ответа сервера
          setState(() => _selectedClient = fullDetails['client']);
        }
      } catch (e) {
        debugPrint('Error fetching full client details: $e');
      }
    }
  }

  Widget _buildField(AppPalette pal, String label, TextEditingController ctrl,
      TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: pal.textSec, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: TextStyle(color: pal.textPri),
          decoration: InputDecoration(
            filled: true,
            fillColor: pal.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ИСПРАВЛЕННЫЙ диалог выбора клиента
// Используем полноценный StatefulWidget с initState() вместо StatefulBuilder.
// Это единственно правильный способ запускать async-загрузку внутри диалога.
// ─────────────────────────────────────────────────────────────────────────────
class _ClientPickerDialog extends StatefulWidget {
  final ApiService api;
  final AppPalette pal;

  const _ClientPickerDialog({required this.api, required this.pal});

  @override
  State<_ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends State<_ClientPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Загружаем всех клиентов сразу при открытии — правильное место для этого
    _loadClients('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await widget.api.searchClients(query);
      // Проверяем mounted ПОСЛЕ await — диалог мог закрыться пока грузились данные
      if (mounted) {
        setState(() {
          _results = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _loadClients(value));
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;

    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Scaffold(
        backgroundColor: pal.bg,
        appBar: AppBar(
          backgroundColor: pal.surface,
          foregroundColor: pal.textPri,
          title: const Text('Выбор клиента'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: pal.textPri),
                decoration: InputDecoration(
                  hintText: 'Поиск по ФИО или ИНН...',
                  hintStyle: TextStyle(color: pal.textSec),
                  prefixIcon: Icon(Icons.search, color: pal.textSec),
                  filled: true,
                  fillColor: pal.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.accent, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: pal.accent),
                    const SizedBox(height: 16),
                    Text('Загрузка...', style: TextStyle(color: pal.textSec)),
                  ],
                ),
              )
            : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 64, color: pal.textSec.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Клиенты не найдены',
                            style: TextStyle(color: pal.textSec)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: pal.border, height: 1),
                    itemBuilder: (_, i) {
                      final c = Map<String, dynamic>.from(_results[i] as Map);
                      final name =
                          (c['full_name'] ?? c['legal_name'] ?? '-').toString();
                      final firstLetter =
                          name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pal.accent.withOpacity(0.15),
                          child: Text(firstLetter,
                              style: TextStyle(
                                  color: pal.accent,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name,
                            style: TextStyle(
                                color: pal.textPri,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('ИНН: ${c['inn'] ?? '-'}',
                            style: TextStyle(color: pal.textSec, fontSize: 13)),
                        trailing: Icon(Icons.chevron_right, color: pal.textSec),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
      ),
    );
  }
}

void _showFullScreenPhoto(BuildContext context, String base64) {
  showDialog(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InteractiveViewer(
          child: Image.memory(
            base64Decode(base64),
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette pal;

  const _SummaryRow(
      {required this.label, required this.value, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label, style: TextStyle(color: pal.textSec))),
          Expanded(
              flex: 3,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: pal.textPri, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
