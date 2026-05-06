import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:nfc_manager/src/platform_tags/nfc_a.dart';
import 'package:nfc_manager/src/platform_tags/iso_dep.dart';
import 'package:nfc_manager/src/platform_tags/iso7816.dart';
import 'bac_crypto.dart';

class ClientRegistrationScreen extends StatefulWidget {
  const ClientRegistrationScreen({super.key});
  @override
  State<ClientRegistrationScreen> createState() => _ClientRegistrationScreenState();
}

class _ClientRegistrationScreenState extends State<ClientRegistrationScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _fullNameCtrl = TextEditingController();
  final _innCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _passSeriesCtrl = TextEditingController(text: 'ID');
  final _passNumberCtrl = TextEditingController();
  final _passIssuedByCtrl = TextEditingController();
  final _passIssuedDateCtrl = TextEditingController();
  final _passExpiryDateCtrl = TextEditingController();
  final _addressRegCtrl = TextEditingController();
  final _addressFactCtrl = TextEditingController();
  final _phoneMainCtrl = TextEditingController(text: '+996');
  final _phoneExtraCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _workplaceCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _gender = 'Мужской';
  String _clientType = 'Физ. лицо';
  String _familyStatus = 'Не женат/Не замужем';
  String _ruralOffice = 'С.Юсупова';
  final List<String> _ruralOffices = ['С.Юсупова', 'Достук', 'Тепе Коргон', 'Нурабад', 'Чек Абад'];
  final List<String> _genders = ['Мужской', 'Женский'];
  final List<String> _familyStatuses = ['Не женат/Не замужем', 'Женат/Замужем', 'В разводе', 'Вдовец/Вдова'];

  @override
  void dispose() {
    _fullNameCtrl.dispose(); _innCtrl.dispose(); _dobCtrl.dispose(); _passNumberCtrl.dispose();
    _passIssuedByCtrl.dispose(); _passIssuedDateCtrl.dispose(); _passExpiryDateCtrl.dispose();
    _addressRegCtrl.dispose(); _addressFactCtrl.dispose(); _phoneMainCtrl.dispose();
    _phoneExtraCtrl.dispose(); _emailCtrl.dispose(); _workplaceCtrl.dispose();
    _positionCtrl.dispose(); _incomeCtrl.dispose(); _notesCtrl.dispose(); super.dispose();
  }

  String _transliterateToCyrillic(String latinText) {
    final Map<String, String> map = {
      'ZH': 'Ж', 'KH': 'Х', 'TS': 'Ц', 'CH': 'Ч', 'SH': 'Ш', 'SHCH': 'Щ', 'YU': 'Ю', 'YA': 'Я',
      'A': 'А', 'B': 'Б', 'V': 'В', 'G': 'Г', 'D': 'Д', 'E': 'Е', 'YO': 'Ё', 'Z': 'З', 'I': 'И', 'Y': 'Й',
      'K': 'К', 'L': 'Л', 'M': 'М', 'N': 'Н', 'O': 'О', 'P': 'Р', 'R': 'Р', 'S': 'С', 'T': 'Т', 'U': 'У',
      'F': 'Ф', 'E': 'Э', 'YU': 'Ю', 'YA': 'Я'
    };
    String result = latinText.toUpperCase();
    map.forEach((key, value) { if (key.length > 1) result = result.replaceAll(key, value); });
    map.forEach((key, value) { if (key.length == 1) result = result.replaceAll(key, value); });
    return result;
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').where((s) => s.isNotEmpty).map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }

  int _calculateCheckDigit(String data) {
    final weights = [7, 3, 1];
    int sum = 0;
    for (int i = 0; i < data.length; i++) {
      int val = 0;
      int charCode = data.codeUnitAt(i);
      if (charCode >= 48 && charCode <= 57) val = charCode - 48;
      else if (charCode >= 65 && charCode <= 90) val = charCode - 55;
      else val = 0;
      sum += val * weights[i % 3];
    }
    return sum % 10;
  }

  String _getMrzInfo(String pNum, String dob, String exp) {
    String cleanPNum = pNum.replaceAll(RegExp(r'[^A-Z0-9]'), '').padRight(9, '<');
    int cd1 = _calculateCheckDigit(cleanPNum);
    String cleanDob = dob.replaceAll('.', '').substring(0, 6);
    int cd2 = _calculateCheckDigit(cleanDob);
    String cleanExp = exp.replaceAll('.', '').substring(0, 6);
    int cd3 = _calculateCheckDigit(cleanExp);
    return "$cleanPNum$cd1$cleanDob$cd2$cleanExp$cd3";
  }

  Future<void> _performBac(dynamic dynamicTech, String mrzInfo, String label) async {
    final crypto = BacCrypto.fromMrz(mrzInfo);
    final rndIcc = await dynamicTech.transceive(data: Uint8List.fromList([0x00, 0x84, 0x00, 0x00, 0x08]));
    if (rndIcc.length < 8) throw "Bad RND.ICC";
    final rndIfd = Uint8List.fromList(List.generate(8, (_) => Random().nextInt(256)));
    final kIfd = Uint8List.fromList(List.generate(16, (_) => Random().nextInt(256)));
    final s = Uint8List.fromList([...rndIfd, ...rndIcc.sublist(0, 8), ...kIfd]);
    final eIfd = crypto.encrypt3DES(crypto.kEnc, s);
    final mIfd = crypto.computeMAC(crypto.kMac, eIfd);
    final authRes = await dynamicTech.transceive(data: Uint8List.fromList([0x00, 0x82, 0x00, 0x00, 0x28, ...eIfd, ...mIfd]));
    String resHex = authRes.map((e) => (e as int).toRadixString(16).padLeft(2, "0")).join("");
    if (!resHex.endsWith("9000")) throw "Auth Failed: $resHex";
  }

  Future<void> _scanPassport() async {
    final picker = ImagePicker();
    bool? proceedFront = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Шаг 1'),
      content: const Text('Пожалуйста, сфотографируйте ЛИЦЕВУЮ сторону паспорта.\n\nСовет: держите телефон ГОРИЗОНТАЛЬНО для лучшего результата.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ОТКРЫТЬ КАМЕРУ'))],
    ));
    if (proceedFront != true) return;
    final frontImage = await picker.pickImage(source: ImageSource.camera); if (frontImage == null) return;
    bool? proceedBack = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Шаг 2'),
      content: const Text('Теперь сфотографируйте ОБОРОТНУЮ сторону паспорта (где ИНН и много букв <<<<).'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ОТКРЫТЬ КАМЕРУ'))],
    ));
    if (proceedBack != true) return;
    final backImage = await picker.pickImage(source: ImageSource.camera); if (backImage == null) return;
    setState(() => _isLoading = true);
    try {
      final frontInput = InputImage.fromFilePath(frontImage.path); final backInput = InputImage.fromFilePath(backImage.path);
      await _parseDualPassportData(frontInput, backInput);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _scanNfc() async {
    String pNum = _passNumberCtrl.text.trim(); String dobRaw = _dobCtrl.text.trim(); String expRaw = _passExpiryDateCtrl.text.trim();
    if (pNum.isEmpty || dobRaw.isEmpty || expRaw.isEmpty) {
      bool? confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Внимание'),
        content: const Text('Номер паспорта и даты не заполнены. NFC-сканирование (BAC) может не сработать. Продолжить?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ВСЕ РАВНО СКАН'))],
      ));
      if (confirm != true) return;
    }
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NFC выключен'))); return; }
    HapticFeedback.mediumImpact(); setState(() => _isLoading = true);
    Timer? timeoutTimer = Timer(const Duration(seconds: 40), () {
      if (_isLoading && mounted) { NfcManager.instance.stopSession(); setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Время ожидания NFC (40с) истекло.'))); }
    });
    try {
      String passNumFix = pNum.toUpperCase();
      if (passNumFix.length == 7 && RegExp(r'^\d+$').hasMatch(passNumFix)) passNumFix = "ID" + passNumFix;
      String dobYY = dobRaw.length == 10 ? dobRaw.substring(8,10) + dobRaw.substring(3,5) + dobRaw.substring(0,2) : "";
      String expYY = expRaw.length == 10 ? expRaw.substring(8,10) + expRaw.substring(3,5) + expRaw.substring(0,2) : "";
      String mrz1 = _getMrzInfo(passNumFix, dobYY, expYY);
      String mrz2 = _getMrzInfo(passNumFix.replaceAll('ID', '') + "<<", dobYY, expYY);
      String nfcKeyInfo = "BAC1: $mrz1\nBAC2: $mrz2";

      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        timeoutTimer.cancel(); HapticFeedback.heavyImpact();
        String apduResponse = "Проверка..."; String log = "Номер: $passNumFix\n"; bool found = false;
        try {
          final tech = IsoDep.from(tag) ?? NfcA.from(tag);
          if (tech != null) {
            final dynamic dynamicTech = tech;
            final apps = [{'name': 'ePassport', 'aid': [0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]}];
            for (var app in apps) {
              final List<int> aid = app['aid'] as List<int>;
              try {
                final selectRes = await dynamicTech.transceive(data: Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, aid.length, ...aid]));
                String resHex = selectRes.map((e) => (e as int).toRadixString(16).padLeft(2, "0")).join("");
                if (resHex.endsWith("9000")) {
                  log += "\nВХОД: ${app['name']} ✅\n";
                  try { await _performBac(dynamicTech, mrz1, "BAC 1"); log += "🔓 АВТОРИЗАЦИЯ УСПЕШНА (BAC 1)!\n";
                  } catch (e1) {
                    try { await _performBac(dynamicTech, mrz2, "BAC 2"); log += "🔓 АВТОРИЗАЦИЯ УСПЕШНА (BAC 2)!\n";
                    } catch (e2) { log += "🔒 ОШИБКА BAC: Ключи не подошли.\n"; }
                  }
                  final targets = [{"name": "DG1 (ФИО)", "path": [0x01, 0x01]}, {"name": "DG13 (Адрес)", "path": [0x01, 0x0D]}];
                  for (var dg in targets) {
                    try {
                      final List<int> p = dg["path"] as List<int>;
                      final selFile = await dynamicTech.transceive(data: Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, ...p]));
                      String sHex = selFile.map((e) => (e as int).toRadixString(16).padLeft(2, "0")).join("");
                      log += "-> ${dg["name"]}: ${sHex == "9000" ? "ОТКРЫТ ✅" : "ЗАМОК ($sHex)"}\n";
                    } catch (e) {}
                  }
                  found = true; break;
                }
              } catch (e) { log += "Error: $e\n"; }
            }
            apduResponse = found ? "Результат:\n$log" : "Приложения не найдены.\n$log";
          }
        } catch (e) { apduResponse = "Ошибка: $e"; }

        if (mounted) {
          setState(() => _isLoading = false); NfcManager.instance.stopSession();
          bool hasOpen = apduResponse.contains('ОТКРЫТ') || apduResponse.contains('УСПЕШНА');
          showDialog(context: context, builder: (context) => AlertDialog(
            title: Text(hasOpen ? '✅ ДОСТУП ПОЛУЧЕН!' : 'NFC Скан'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Статус безопасности:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(apduResponse, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: hasOpen ? Colors.green.shade900 : Colors.black87)),
              const Divider(height: 30),
              const Text('Ключи BAC:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(nfcKeyInfo, style: const TextStyle(color: Colors.blue, fontFamily: 'monospace', fontSize: 11)),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ПОНЯТНО'))],
          ));
        }
      });
    } catch (e) { timeoutTimer.cancel(); if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _parseDualPassportData(InputImage front, InputImage back) async {
    final cyrScript = TextRecognitionScript.values.firstWhere((e) => e.name.toLowerCase() == 'cyrillic', orElse: () => TextRecognitionScript.latin);
    final latRec = TextRecognizer(script: TextRecognitionScript.latin); final cyrRec = TextRecognizer(script: cyrScript);
    try {
      final frontText = await cyrRec.processImage(front);
      String? detCyrName; String? detPassNum; final passRegex = RegExp(r'\bID\d{7}\b');
      double? sY, nY, pY; Map<double, String> cand = {};
      for (TextBlock b in frontText.blocks) {
        for (TextLine l in b.lines) {
          final t = l.text.trim(); final u = t.toUpperCase(); final y = l.boundingBox.top.toDouble();
          if (u.contains('SURNAME')) sY = y; if (u.contains('NAME') && !u.contains('SURNAME')) nY = y; if (u.contains('PATRONYMIC')) pY = y;
          if (t.length > 2 && !u.contains('SURNAME') && !u.contains('NAME') && !u.contains('КЫРГЫЗ')) cand[y] = t;
        }
      }
      String? find(double? lY) {
        if (lY == null) return null; double mD = 9999; String? b;
        for (var e in cand.entries) { double d = e.key - lY; if (d > 10 && d < 80 && d < mD) { mD = d; b = e.value; } }
        return b;
      }
      String? s = find(sY); String? n = find(nY); String? p = find(pY);
      if (s != null || n != null) detCyrName = _capitalizeWords([s ?? '', n ?? '', p ?? ''].join(' ').trim());
      final backText = await latRec.processImage(back);
      String? detInn, detDob, detAuth, detLatName; final innRegex = RegExp(r'\b[12]\d{13}\b');
      for (TextBlock b in backText.blocks) {
        for (TextLine l in b.lines) {
          final text = l.text.toUpperCase().trim(); final tNS = text.replaceAll(' ', '');
          final iM = innRegex.firstMatch(tNS); if (iM != null) { detInn = iM.group(0);
            if (detInn!.length == 14) { detDob = "${detInn.substring(1,3)}.${detInn.substring(3,5)}.${detInn.substring(5,9)}";
              setState(() => _gender = detInn!.startsWith('2') ? 'Мужской' : 'Женский'); } }
          if (text.contains('<<')) { final mrzRegex = RegExp(r'([A-Z]+)<<([A-Z<]+)'); final mM = mrzRegex.firstMatch(text); if (mM != null) {
            detLatName = _capitalizeWords("${mM.group(1)} ${mM.group(2)?.replaceAll('<', ' ').trim()}"); } }
          if (detPassNum == null && text.contains('ID')) { final m = passRegex.firstMatch(tNS); if (m != null) detPassNum = m.group(0); }
          if (text.contains('MKK') || text.contains('МКК')) detAuth = l.text.trim();
        }
      }
      setState(() {
        String fN = (detCyrName != null && detCyrName!.contains(RegExp(r'[а-яА-ЯёЁ]'))) ? detCyrName! : (detLatName != null ? _transliterateToCyrillic(detLatName!) : '');
        _fullNameCtrl.text = _capitalizeWords(fN.replaceAll(RegExp(r'KGZ|PASSPORT|ID|КЫРГЫЗ|CARD', caseSensitive: false), '').trim());
        if (detInn != null) _innCtrl.text = detInn; if (detDob != null) _dobCtrl.text = detDob;
        if (detAuth != null) _passIssuedByCtrl.text = detAuth; if (detPassNum != null) _passNumberCtrl.text = detPassNum!.replaceAll('ID', '');
        final dateRegex = RegExp(r'\b(\d{2})\.(\d{2})\.(\d{4})\b'); List<String> foundDates = [];
        for (var res in [frontText, backText]) { for (TextBlock b in res.blocks) { for (TextLine l in b.lines) { final m = dateRegex.firstMatch(l.text); if (m != null) foundDates.add(m.group(0)!); } } }
        foundDates = foundDates.toSet().toList();
        if (foundDates.length >= 2) { try {
          foundDates.sort((a, b) => DateFormat('dd.MM.yyyy').parse(a).compareTo(DateFormat('dd.MM.yyyy').parse(b)));
          final otherDates = foundDates.where((d) => d != detDob).toList();
          if (otherDates.isNotEmpty) { _passExpiryDateCtrl.text = otherDates.last; if (otherDates.length > 1) _passIssuedDateCtrl.text = otherDates.first; }
        } catch (e) {} }
      });
    } finally { latRec.close(); cyrRec.close(); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'full_name': _fullNameCtrl.text, 'inn': _innCtrl.text, 'status': 'Активен', 'registration_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'client_type': _clientType, 'gender': _gender, 'date_of_birth': _dobCtrl.text, 'passport_series': _passSeriesCtrl.text, 'passport_number': _passNumberCtrl.text,
        'passport_issued_by': _passIssuedByCtrl.text, 'passport_issued_date': _passIssuedDateCtrl.text, 'passport_expiry_date': _passExpiryDateCtrl.text,
        'citizenship': 'Кыргызстан', 'address_registration': _addressRegCtrl.text, 'rural_office': _ruralOffice,
        'address_factual': _addressFactCtrl.text.isEmpty ? _addressRegCtrl.text : _addressFactCtrl.text, 'phone_main': _phoneMainCtrl.text,
        'phone_extra': _phoneExtraCtrl.text, 'email': _emailCtrl.text, 'workplace': _workplaceCtrl.text, 'position': _positionCtrl.text,
        'monthly_income': double.tryParse(_incomeCtrl.text) ?? 0, 'family_status': _familyStatus, 'notes': _notesCtrl.text,
      };
      await _api.createClient(data);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Успех'), backgroundColor: Colors.green)); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Scaffold(
      backgroundColor: pal.bg, appBar: AppBar(backgroundColor: pal.bg, title: Text('Регистрация', style: TextStyle(color: pal.textPri)), iconTheme: IconThemeData(color: pal.textPri)),
      body: Stack(children: [
        Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
          _buildHeader(pal), const SizedBox(height: 24), _buildSectionTitle(pal, 'Инфо'),
          _buildTextField(pal, _fullNameCtrl, 'ФИО', Icons.person, required: true),
          _buildTextField(pal, _innCtrl, 'ИНН', Icons.badge, required: true, maxLength: 14),
          _buildDropdown(pal, 'Пол', _gender, _genders, (v) => setState(() => _gender = v!)),
          _buildTextField(pal, _dobCtrl, 'Дата рождения', Icons.calendar_today),
          const SizedBox(height: 24), _buildSectionTitle(pal, 'Паспорт'),
          Row(children: [ Expanded(child: _buildTextField(pal, _passSeriesCtrl, 'Серия', Icons.numbers)), const SizedBox(width: 12), Expanded(flex: 2, child: _buildTextField(pal, _passNumberCtrl, 'Номер', Icons.numbers, required: true)) ]),
          _buildTextField(pal, _passIssuedByCtrl, 'Кем выдан', Icons.account_balance),
          _buildTextField(pal, _passIssuedDateCtrl, 'Дата выдачи', Icons.date_range),
          _buildTextField(pal, _passExpiryDateCtrl, 'Срок', Icons.event_busy),
          const SizedBox(height: 24), _buildSectionTitle(pal, 'Контакты'),
          _buildTextField(pal, _phoneMainCtrl, 'Телефон', Icons.phone, required: true),
          _buildTextField(pal, _addressRegCtrl, 'Адрес прописки', Icons.home),
          _buildDropdown(pal, 'Айыл окмоту', _ruralOffice, _ruralOffices, (v) => setState(() => _ruralOffice = v!)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _isLoading ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54)), child: const Text('Сохранить')),
        ])),
        if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
      ]),
    );
  }

  Widget _buildHeader(AppPalette pal) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Column(children: [
      const Icon(Icons.camera_alt, color: Color(0xFF2563EB), size: 40), const SizedBox(height: 12),
      const Text('Автозаполнение', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: _scanPassport, icon: const Icon(Icons.qr_code_scanner), label: const Text('Фото'))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(onPressed: _scanNfc, icon: const Icon(Icons.nfc), label: const Text('NFC'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700))),
      ]),
    ]));
  }

  Widget _buildSectionTitle(AppPalette pal, String title) { return Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(title, style: TextStyle(color: pal.textPri, fontSize: 17, fontWeight: FontWeight.bold))); }
  Widget _buildTextField(AppPalette pal, TextEditingController ctrl, String label, IconData icon, { bool required = false, int? maxLength }) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: ctrl, maxLength: maxLength, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder())));
  }
  Widget _buildDropdown(AppPalette pal, String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: DropdownButtonFormField<String>(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }
}