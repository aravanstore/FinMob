import 'dart:async';
// =============================================================================
// ВНИМАНИЕ! ЭТОТ ФАЙЛ РАБОТАЕТ. 
// НЕ ИЗМЕНЯТЬ И НЕ ПЕРЕЗАПИСЫВАТЬ БЕЗ ЯВНОГО РАЗРЕШЕНИЯ ПОЛЬЗОВАТЕЛЯ!
// THIS FILE WORKS. DO NOT MODIFY WITHOUT PERMISSION!
// =============================================================================
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:dmrtd/dmrtd.dart';
import 'package:logging/logging.dart';
import 'bac_crypto.dart';

class ClientRegistrationScreenNew extends StatefulWidget {
  const ClientRegistrationScreenNew({super.key});
  @override
  State<ClientRegistrationScreenNew> createState() => _ClientRegistrationScreenNewState();
}

class _ClientRegistrationScreenNewState extends State<ClientRegistrationScreenNew> {
  final _api = ApiService();
  String? _nfcRawDoc, _nfcRawDob, _nfcRawExp;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Uint8List? _nfcPhoto;
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
      'SHCH': 'Щ', 'SH': 'Ш', 'CH': 'Ч', 'ZH': 'Ж', 'KH': 'Х', 'TS': 'Ц', 'YU': 'Ю', 'YA': 'Я',
      'A': 'А', 'B': 'Б', 'V': 'В', 'G': 'Г', 'D': 'Д', 'E': 'Е', 'YO': 'Ё', 'Z': 'З', 'I': 'И', 'J': 'Й',
      'K': 'К', 'L': 'Л', 'M': 'М', 'N': 'Н', 'O': 'О', 'P': 'П', 'R': 'Р', 'S': 'С', 'T': 'Т', 'U': 'У',
      'F': 'Ф', 'Y': 'Ы'
    };
    String result = latinText.toUpperCase();
    map.forEach((key, value) => result = result.replaceAll(key, value));
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
    String cleanDob = dob.replaceAll('.', '');
    if (cleanDob.length == 8) cleanDob = cleanDob.substring(4, 6) + cleanDob.substring(2, 4) + cleanDob.substring(0, 2);
    else if (cleanDob.length == 6) {} // уже в формате YYMMDD
    int cd2 = _calculateCheckDigit(cleanDob);
    String cleanExp = exp.replaceAll('.', '');
    if (cleanExp.length == 8) cleanExp = cleanExp.substring(4, 6) + cleanExp.substring(2, 4) + cleanExp.substring(0, 2);
    int cd3 = _calculateCheckDigit(cleanExp);
    return "$cleanPNum$cd1$cleanDob$cd2$cleanExp$cd3";
  }

  Future<SecureSession> _performBac(dynamic tech, String mrzInfo) async {
    final crypto = BacCrypto.fromMrz(mrzInfo);
    final rndIcc = await tech.transceive(data: Uint8List.fromList([0x00, 0x84, 0x00, 0x00, 0x08]));
    if (rndIcc.length < 10) throw "GET CHALLENGE failed: ${hexEncode(rndIcc)}";
    final rndIccData = Uint8List.fromList(rndIcc.sublist(0, 8));
    final rand = Random.secure();
    final rndIfd = Uint8List.fromList(List.generate(8, (_) => rand.nextInt(256)));
    final kIfd = Uint8List.fromList(List.generate(16, (_) => rand.nextInt(256)));
    final s = Uint8List.fromList([...rndIfd, ...rndIccData, ...kIfd]);
    final eIfd = desedeCbcEncrypt(crypto.kEnc, s);
    final mIfd = computeMAC(crypto.kMac, eIfd);
    final authCmd = Uint8List.fromList([0x00, 0x82, 0x00, 0x00, 0x28, ...eIfd, ...mIfd, 0x28]);
    final authRes = await tech.transceive(data: authCmd);
    String resHex = hexEncode(authRes);
    if (!resHex.endsWith("9000") || authRes.length < 42) throw "MUTUAL AUTH failed: $resHex";
    final eIcc = Uint8List.fromList(authRes.sublist(0, 32));
    final decrypted = desedeCbcDecrypt(crypto.kEnc, eIcc);
    final kIcc = Uint8List.fromList(decrypted.sublist(16, 32));
    return SecureSession.fromBac(kIfd: kIfd, kIcc: kIcc, rndIfd: rndIfd, rndIcc: rndIccData);
  }

  Future<Uint8List?> _readFileSecure(dynamic tech, SecureSession session, List<int> fileId) async {
    final selApdu = session.wrapApdu(0x00, 0xA4, 0x02, 0x0C, data: Uint8List.fromList(fileId));
    final selRes = await tech.transceive(data: selApdu);
    if (!hexEncode(selRes).endsWith("9000")) throw "SELECT fail";
    final allBytes = <int>[];
    int offset = 0;
    int? totalLen;
    while (true) {
      int hi = (offset >> 8) & 0xFF;
      int lo = offset & 0xFF;
      final readApdu = session.wrapApdu(0x00, 0xB0, hi, lo, le: 0x00);
      final readRes = await tech.transceive(data: readApdu);
      final data = session.unwrapResponse(readRes);
      if (data == null || data.isEmpty) break;
      if (offset == 0 && data.length > 4) {
        int pos = 1; int len = data[pos++];
        if (len == 0x81) { totalLen = data[pos] + pos + 1; }
        else if (len == 0x82) { totalLen = ((data[pos] << 8) | data[pos + 1]) + pos + 2; }
        else { totalLen = len + pos; }
      }
      allBytes.addAll(data);
      offset += data.length;
      if (totalLen != null && allBytes.length >= totalLen) break;
      if (data.length < 0x20) break;
    }
    return allBytes.isNotEmpty ? Uint8List.fromList(allBytes) : null;
  }

  void _applyMrzData(dynamic mrz) {
    setState(() {
      try {
        String sName = (mrz.surname ?? '').toString().replaceAll('<', ' ').trim();
        String gNames = (mrz.givenNames ?? '').toString().replaceAll('<', ' ').trim();
        if (sName.isNotEmpty || gNames.isNotEmpty) {
          String fullLat = '$sName $gNames'.trim();
          String cyr = _capitalizeWords(_transliterateToCyrillic(fullLat));
          _fullNameCtrl.text = cyr.replaceAll(RegExp(r'KGZ|PASSPORT|ID|КЫРГЫЗ|CARD', caseSensitive: false), '').trim();
        }

        String docRaw = (mrz.documentNumber ?? '').toString()
            .replaceAll('<', '')
            .replaceAll('O', '0')
            .replaceAll('I', '1');
        if (docRaw.isNotEmpty) {
          final seriesMatch = RegExp(r'^([A-Z]{2})(\d+)$').firstMatch(docRaw);
          if (seriesMatch != null) {
            _passSeriesCtrl.text = seriesMatch.group(1)!;
            _passNumberCtrl.text = seriesMatch.group(2)!;
          } else if (docRaw.length > 2 && (docRaw.startsWith('ID') || docRaw.startsWith('AN') || docRaw.startsWith('IK'))) {
            _passSeriesCtrl.text = docRaw.substring(0, 2);
            _passNumberCtrl.text = docRaw.substring(2);
          } else {
            _passNumberCtrl.text = docRaw;
          }
        }

        if (mrz.dateOfBirth != null) {
          if (mrz.dateOfBirth is DateTime) _dobCtrl.text = DateFormat('dd.MM.yyyy').format(mrz.dateOfBirth);
          else _dobCtrl.text = mrz.dateOfBirth.toString();
        }
        if (mrz.dateOfExpiry != null) {
          if (mrz.dateOfExpiry is DateTime) _passExpiryDateCtrl.text = DateFormat('dd.MM.yyyy').format(mrz.dateOfExpiry);
          else _passExpiryDateCtrl.text = mrz.dateOfExpiry.toString();
        }
        if (mrz.sex != null) _gender = mrz.sex.toString().startsWith('M') ? 'Мужской' : 'Женский';
        
        final opt = (mrz.optionalData ?? '').toString().replaceAll('<', '').replaceAll('O', '0');
        if (opt.length >= 14 && RegExp(r'^\d{14}').hasMatch(opt)) {
          _innCtrl.text = opt.substring(0, 14);
        }
      } catch (_) {}
    });
  }

  void _tryParseDg13(Uint8List dg13Data) {
    try {
      final nodes = parseTlv(dg13Data);
      final allText = <String>[];
      void extractStrings(List<TlvNode> list) {
        for (var n in list) {
          try {
            final s = utf8.decode(n.value).trim();
            if (s.length > 2) allText.add(s);
          } catch (_) {}
          if (n.value.length > 4) extractStrings(parseTlv(n.value));
        }
      }
      extractStrings(nodes);
      for (var text in allText) {
        if (RegExp(r'[А-ЯЁа-яё]{2,}\s+[А-ЯЁа-яё]').hasMatch(text) && text.length < 100) {
          setState(() => _fullNameCtrl.text = _capitalizeWords(text));
        }
        if ((text.contains('обл') || text.contains('р-н') || text.contains('ул') || text.contains('г.') || text.contains('с.')) && text.length < 200) {
          setState(() { if (_addressRegCtrl.text.isEmpty) _addressRegCtrl.text = text; });
        }
        if (_innCtrl.text.isEmpty) {
          final innMatch = RegExp(r'[12]\d{13}').firstMatch(text);
          if (innMatch != null) setState(() => _innCtrl.text = innMatch.group(0)!);
        }
      }
    } catch (_) {}
  }

  void _extractImage(Uint8List dg2) {
    for (int i = 0; i < dg2.length - 3; i++) {
      if (dg2[i] == 0xFF && dg2[i+1] == 0xD8 && dg2[i+2] == 0xFF) { setState(() => _nfcPhoto = dg2.sublist(i)); return; }
    }
    for (int i = 0; i < dg2.length - 8; i++) {
      if (dg2[i] == 0x00 && dg2[i+1] == 0x00 && dg2[i+2] == 0x00 && dg2[i+3] == 0x0C && dg2[i+4] == 0x6A && dg2[i+5] == 0x50) {
        setState(() => _nfcPhoto = dg2.sublist(i)); return;
      }
    }
  }

  Future<void> _scanNfcModern() async {
    String pSeries = _passSeriesCtrl.text.trim().toUpperCase();
    String pNum = _passNumberCtrl.text.trim().toUpperCase().replaceAll('O', '0').replaceAll('I', '1');
    final String dobRaw  = _dobCtrl.text.trim();
    final String expRaw  = _passExpiryDateCtrl.text.trim();

    if (pNum.isEmpty || dobRaw.isEmpty || expRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните номер паспорта и даты!')));
      return;
    }

    setState(() => _isLoading = true);
    final scanCtx = context;
    showDialog(context: scanCtx, barrierDismissible: false, builder: (_) => const AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(), SizedBox(height: 20),
        Text('Приложите паспорт к телефону\nи держите неподвижно', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));

    String log = ''; bool success = false;
    final nfc = NfcProvider();
    try {
      await nfc.connect();
      log += '✅ NFC подключен\n';
      final passport = Passport(nfc);

      DateTime parsedDob; DateTime parsedExp;
      try {
        parsedDob = DateFormat('dd.MM.yyyy').parse(dobRaw);
        parsedExp = DateFormat('dd.MM.yyyy').parse(expRaw);
      } catch (_) {
        String d = dobRaw.replaceAll(RegExp(r'\D'), '');
        String e = expRaw.replaceAll(RegExp(r'\D'), '');
        if (d.length == 8) d = d.substring(6) + d.substring(4, 6) + d.substring(2, 4);
        if (e.length == 8) e = e.substring(6) + e.substring(4, 6) + e.substring(2, 4);
        final dy = int.parse(d.substring(0, 2)); final ey = int.parse(e.substring(0, 2));
        parsedDob = DateTime(dy <= 30 ? 2000 + dy : 1900 + dy, int.parse(d.substring(2, 4)), int.parse(d.substring(4, 6)));
        parsedExp = DateTime(ey <= 30 ? 2000 + ey : 1900 + ey, int.parse(e.substring(2, 4)), int.parse(e.substring(4, 6)));
      }

      final digitsOnly = pNum.replaceAll(RegExp(r'[^0-9]'), '');
      final withSeries = (pSeries + pNum).replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final seen = <String>{}; final variants = <String>[];
      void add(String s) { if (s.isEmpty) return; final p = s.length <= 9 ? s.padRight(9, '<') : s.substring(0, 9); if (seen.add(p)) variants.add(p); }
      add(withSeries); add(digitsOnly); add(digitsOnly.padLeft(9, '0')); add('AN$digitsOnly');
      
      EfCardAccess? cardAccess;
      try { cardAccess = await passport.readEfCardAccess(); log += '📋 EF.CardAccess: PACE\n'; } catch (_) {}

      bool sessionStarted = false;
      outer: for (final docNum in variants) {
        for (final dayOff in [0, 1, -1]) {
          final expTry = parsedExp.add(Duration(days: dayOff));
          if (cardAccess != null) {
            try {
              await passport.startSessionPACE(DBAKey(docNum, parsedDob, expTry, paceMode: true), cardAccess);
              log += '🔓 PACE OK!\n'; sessionStarted = true; break outer;
            } catch (e) { if (e.toString().contains('Tag was lost')) break outer; }
          }
          try {
            await passport.startSession(DBAKey(docNum, parsedDob, expTry));
            log += '🔓 BAC OK!\n'; sessionStarted = true; break outer;
          } catch (e) { if (e.toString().contains('Tag lost')) break outer; }
        }
      }

      if (!sessionStarted) throw 'Ключ не подошёл или чип сбросил соединение.';

      // Чтение данных
      try {
        final dg1 = await passport.readEfDG1();
        if (dg1.mrz != null) {
          _applyMrzData(dg1.mrz!);
          success = true;
          log += '📄 DG1 OK\n';
        }
      } catch (e) {
        log += '⚠ DG1 ошибка: $e\n';
      }

      try {
        final dg2 = await passport.readEfDG2();
        if (dg2.imageData != null) {
          _extractImage(dg2.imageData!);
          log += '🖼 DG2 OK\n';
        }
      } catch (e) {
        log += '⚠ DG2 ошибка: $e\n';
      }

      // DG11 и DG12 — читаем тихо, не пугаем пользователя ошибками парсинга дат
      try {
        final dg11 = await passport.readEfDG11();
        if (dg11.nameOfHolder != null && dg11.nameOfHolder!.isNotEmpty) {
          final name = dg11.nameOfHolder!.replaceAll('<', ' ').trim();
          if (name.isNotEmpty && mounted) {
            setState(() => _fullNameCtrl.text = _capitalizeWords(name));
            log += '👤 DG11 OK\n';
          }
        }
      } catch (_) {}

      try {
        final dg12 = await passport.readEfDG12();
        if (dg12.issuingAuthority != null && mounted) setState(() => _passIssuedByCtrl.text = dg12.issuingAuthority!);
        if (dg12.dateOfIssue != null && mounted) setState(() => _passIssuedDateCtrl.text = DateFormat('dd.MM.yyyy').format(dg12.dateOfIssue!));
        log += '🏛 DG12 OK\n';
      } catch (_) {}

    } catch (e) { log += '❌ $e\n'; } finally {
      try { await nfc.disconnect(); } catch (_) {}
      if (mounted) {
        setState(() => _isLoading = false); Navigator.of(scanCtx, rootNavigator: true).pop();
        showDialog(context: context, builder: (_) => AlertDialog(title: Text(success ? '✅ Успех' : '⚠ Ошибка'), content: SingleChildScrollView(child: Text(log)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      }
    }
  }

  Future<void> _scanNfc() async {
    String pSer = _passSeriesCtrl.text.trim().toUpperCase().replaceAll('O', '0').replaceAll('I', '1');
    String pNum = _passNumberCtrl.text.trim().toUpperCase().replaceAll('O', '0').replaceAll('I', '1');
    String dobRaw = _dobCtrl.text.trim();
    String expRaw = _passExpiryDateCtrl.text.trim();
    if (pNum.isEmpty || dobRaw.isEmpty || expRaw.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала заполните данные паспорта!')));
       return;
    }
    setState(() => _isLoading = true);
    final scanCtx = context;
    showDialog(context: scanCtx, barrierDismissible: false, builder: (_) => const AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(), SizedBox(height: 20),
        const Text('Приложите карту (BAC)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
    String log = ""; bool success = false;
    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          final tech = IsoDep.from(tag); if (tech == null) throw "IsoDep null";
          final dynamic dynTech = tech;
          await dynTech.transceive(data: Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x07, 0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]));
          
          String mrzInfo = _getMrzInfo(pSer + pNum, dobRaw, expRaw);
          final session = await _performBac(dynTech, mrzInfo);
          log += "🔓 BAC OK\n";
          
          final dg1 = await _readFileSecure(dynTech, session, [0x01, 0x01]);
          if (dg1 != null) {
            final mrzNode = TlvNode(0, dg1).find(0x5F1F);
            if (mrzNode != null) {
              final mrz = parseMrz(mrzNode.value);
              if (mrz != null) {
                _applyMrzData(mrz);
                success = true; log += "📄 DG1 OK\n";
              }
            }
          }
          final dg2 = await _readFileSecure(dynTech, session, [0x01, 0x02]);
          if (dg2 != null) { log += "🖼 DG2 OK\n"; _extractImage(dg2); }
          final dg13 = await _readFileSecure(dynTech, session, [0x01, 0x0D]);
          if (dg13 != null) { log += "📝 DG13 OK\n"; _tryParseDg13(dg13); }
        } catch (e) { log += "❌ Error: $e\n"; }
        finally {
          NfcManager.instance.stopSession();
          if (mounted) {
            setState(() => _isLoading = false); Navigator.of(scanCtx, rootNavigator: true).pop();
            showDialog(context: context, builder: (_) => AlertDialog(title: Text(success ? '✅ Готово' : '⚠ Ошибка'), content: SingleChildScrollView(child: Text(log)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false); Navigator.of(scanCtx, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('NFC Error: $e')));
    }
  }

  Future<void> _onScanComplete(File front, File back) async {
    setState(() => _isLoading = true);
    try {
      final frontInput = InputImage.fromFilePath(front.path);
      final backInput = InputImage.fromFilePath(back.path);
      await _parseDualPassportData(frontInput, backInput);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _parseDualPassportData(InputImage front, InputImage back) async {
    final latRec = TextRecognizer(script: TextRecognitionScript.latin);
    final cyrRec = TextRecognizer(script: TextRecognitionScript.values.firstWhere((e) => e.name.toLowerCase() == 'cyrillic', orElse: () => TextRecognitionScript.latin));
    try {
      final frontText = await cyrRec.processImage(front);
      final backText = await latRec.processImage(back);
      
      String? cyrName, detInn, detDob, detAuth, rDoc, rDob, rExp;
      
      for (TextBlock b in frontText.blocks) {
        for (TextLine l in b.lines) {
          final t = l.text.trim();
          // Более гибкий поиск: минимум 3 буквы, только кириллица, пробелы и дефисы
          if (RegExp(r'^[А-ЯЁ\s-]{3,}$').hasMatch(t) && 
              !t.contains('КЫРГЫЗ') && 
              !t.contains('ПАСПОРТ') &&
              !t.contains('РЕСПУБЛИКА') &&
              !t.contains('ID')) {
            if (cyrName == null || t.length > cyrName.length) cyrName = t;
          }
        }
      }

      String backFull = backText.text.replaceAll(' ', '').toUpperCase();
      final mrzDocMatch = RegExp(r'I<KGZ([A-Z0-9<]{9})').firstMatch(backFull);
      if (mrzDocMatch != null) rDoc = mrzDocMatch.group(1);
      final mrzDataMatch = RegExp(r'(\d{6})\d[MF<](\d{6})\d').firstMatch(backFull);
      if (mrzDataMatch != null) { rDob = mrzDataMatch.group(1); rExp = mrzDataMatch.group(2); }

      final dateRegex = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})');
      List<String> allDates = [];
      for (var res in [frontText, backText]) {
        for (TextBlock b in res.blocks) {
          for (TextLine l in b.lines) {
            final t = l.text.toUpperCase();
            final cleanT = t.replaceAll(' ', '');
            final innMatch = RegExp(r'\b[12]\d{13}\b').firstMatch(cleanT);
            if (innMatch != null) detInn = innMatch.group(0);
            for (var m in dateRegex.allMatches(l.text)) allDates.add(m.group(0)!);
            if ((t.contains('MKK') || t.contains('ОРГАН') || t.contains('МКК')) && !t.contains('КЫРГЫЗ')) {
              detAuth = l.text.replaceAll(RegExp(r'Authority|/|UpraH', caseSensitive: false), '').trim();
            }
          }
        }
      }

      setState(() {
        _nfcRawDoc = rDoc; _nfcRawDob = rDob; _nfcRawExp = rExp;
        if (cyrName != null) _fullNameCtrl.text = _capitalizeWords(cyrName);
        if (detInn != null) {
          _innCtrl.text = detInn;
          detDob = "${detInn!.substring(1,3)}.${detInn.substring(3,5)}.${detInn.substring(5,9)}";
          _dobCtrl.text = detDob!;
        }
        allDates = allDates.toSet().toList();
        if (allDates.isNotEmpty) {
           try {
             allDates.sort((a,b) => DateFormat('dd.MM.yyyy').parse(a).compareTo(DateFormat('dd.MM.yyyy').parse(b)));
             if (detDob != null) {
               final others = allDates.where((d) => d != detDob).toList();
               if (others.isNotEmpty) {
                 _passExpiryDateCtrl.text = others.last;
                 if (others.length > 1) _passIssuedDateCtrl.text = others.first;
               }
             } else {
               _dobCtrl.text = allDates.first;
               if (allDates.length > 1) _passExpiryDateCtrl.text = allDates.last;
               if (allDates.length > 2) _passIssuedDateCtrl.text = allDates[1];
             }
           } catch (_) {}
        }
        if (detAuth != null) _passIssuedByCtrl.text = detAuth;
        if (rDoc != null) {
          String doc = rDoc.replaceAll('<', '');
          if (doc.length >= 8) { _passSeriesCtrl.text = doc.substring(0, 2); _passNumberCtrl.text = doc.substring(2); }
          else if (doc.startsWith('IK') || doc.startsWith('ID') || doc.startsWith('AN')) { _passSeriesCtrl.text = doc.substring(0, 2); _passNumberCtrl.text = doc.substring(2); }
          else { _passNumberCtrl.text = doc; }
        }
        if (_dobCtrl.text.isEmpty && rDob != null && rDob.length == 6) { try { _dobCtrl.text = "${rDob.substring(4, 6)}.${rDob.substring(2, 4)}.20${rDob.substring(0, 2)}"; } catch(_) {} }
        if (_passExpiryDateCtrl.text.isEmpty && rExp != null && rExp.length == 6) { try { _passExpiryDateCtrl.text = "${rExp.substring(4, 6)}.${rExp.substring(2, 4)}.20${rExp.substring(0, 2)}"; } catch(_) {} }
      });
    } finally { latRec.close(); cyrRec.close(); }
  }

  Future<void> _scanPassport() async {
    final picker = ImagePicker();
    final front = await picker.pickImage(source: ImageSource.camera); if (front == null) return;
    final back = await picker.pickImage(source: ImageSource.camera); if (back == null) return;
    await _onScanComplete(File(front.path), File(back.path));
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
      if (_nfcPhoto != null) Padding(padding: const EdgeInsets.only(bottom: 16.0), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_nfcPhoto!, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 80))))
      else const Icon(Icons.camera_alt, color: Color(0xFF2563EB), size: 40),
      const SizedBox(height: 12),
      const Text('Автозаполнение', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: _scanPassport, icon: const Icon(Icons.qr_code_scanner), label: const Text('Фото'))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(onPressed: _scanNfc, icon: const Icon(Icons.nfc), label: const Text('NFC (Старый)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
      ]),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _scanNfcModern,
        icon: const Icon(Icons.nfc),
        label: const Text('NFC (Новый 2024+)'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, minimumSize: const Size(double.infinity, 44)),
      ),
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
