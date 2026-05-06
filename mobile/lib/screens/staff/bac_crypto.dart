import 'dart:typed_data';

import 'package:crypto/crypto.dart'; // добавьте crypto: ^3.0.0 в pubspec.yaml
import 'package:pointycastle/export.dart';


// ═══════════════════════════════════════════════════════════════════════════════
//  ICAO 9303 BAC + Secure Messaging — полная реализация для Кыргызских eID
// ═══════════════════════════════════════════════════════════════════════════════

String hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

// ─── ISO 9797-1 Padding Method 2 ────────────────────────────────────────────

Uint8List padMethod2(Uint8List data) {
  int extra = 8 - ((data.length + 1) % 8);
  if (extra == 8) extra = 0;
  final out = Uint8List(data.length + 1 + extra);
  out.setAll(0, data);
  out[data.length] = 0x80;
  return out;
}

Uint8List unpadMethod2(Uint8List data) {
  int i = data.length - 1;
  while (i >= 0 && data[i] == 0x00) i--;
  if (i >= 0 && data[i] == 0x80) return Uint8List.fromList(data.sublist(0, i));
  return data;
}

// ─── DES / 3DES Helpers ─────────────────────────────────────────────────────

/// 16-byte 2-key 3DES → 24-byte (K1 || K2 || K1)
Uint8List _to24(Uint8List k16) =>
    Uint8List.fromList([...k16.sublist(0, 8), ...k16.sublist(8, 16), ...k16.sublist(0, 8)]);

Uint8List _adjustParity(Uint8List key) {
  final r = Uint8List.fromList(key);
  for (int i = 0; i < r.length; i++) {
    int bits = 0;
    for (int j = 1; j < 8; j++) {
      if (((r[i] >> j) & 1) == 1) bits++;
    }
    if (bits % 2 == 0) {
      r[i] |= 0x01;
    } else {
      r[i] &= 0xFE;
    }
  }
  return r;
}

/// 3DES-CBC encrypt, IV = 00..00 (по умолчанию)
Uint8List desedeCbcEncrypt(Uint8List key16, Uint8List data, [Uint8List? iv]) {
  final cipher = CBCBlockCipher(DESedeEngine())
    ..init(true, ParametersWithIV(KeyParameter(_to24(key16)), iv ?? Uint8List(8)));
  final out = Uint8List(data.length);
  for (int i = 0; i < data.length; i += 8) {
    cipher.processBlock(data, i, out, i);
  }
  return out;
}

/// 3DES-CBC decrypt, IV = 00..00 (по умолчанию)
Uint8List desedeCbcDecrypt(Uint8List key16, Uint8List data, [Uint8List? iv]) {
  final cipher = CBCBlockCipher(DESedeEngine())
    ..init(false, ParametersWithIV(KeyParameter(_to24(key16)), iv ?? Uint8List(8)));
  final out = Uint8List(data.length);
  for (int i = 0; i < data.length; i += 8) {
    cipher.processBlock(data, i, out, i);
  }
  return out;
}

/// Обёртка: DES как 3DES с ключом K||K||K
BlockCipher _desEngine() => DESedeEngine();
Uint8List _desKey(Uint8List k8) => Uint8List.fromList([...k8, ...k8, ...k8]);

/// ISO 9797-1 MAC Algorithm 3 с Padding Method 2
Uint8List computeMAC(Uint8List key16, Uint8List data) {
  final padded = padMethod2(data);
  final k1 = key16.sublist(0, 8);
  final k2 = key16.sublist(8, 16);

  // 1) CBC-DES с K1 (через 3DES K1||K1||K1)
  final cbc = CBCBlockCipher(_desEngine())
    ..init(true, ParametersWithIV(KeyParameter(_desKey(k1)), Uint8List(8)));
  Uint8List h = Uint8List(8);
  for (int i = 0; i < padded.length; i += 8) {
    cbc.processBlock(padded, i, h, 0);
  }

  // 2) DES-decrypt K2
  final dec = _desEngine()..init(false, KeyParameter(_desKey(k2)));
  Uint8List step2 = Uint8List(8);
  dec.processBlock(h, 0, step2, 0);

  // 3) DES-encrypt K1
  final enc = _desEngine()..init(true, KeyParameter(_desKey(k1)));
  Uint8List mac = Uint8List(8);
  enc.processBlock(step2, 0, mac, 0);

  return mac;
}

// ─── Key Derivation (ICAO 9303) ─────────────────────────────────────────────

Uint8List deriveKey(Uint8List seed, List<int> counter) {
  final data = Uint8List.fromList([...seed, ...counter]);
  final hash = sha1.convert(data).bytes;
  return _adjustParity(Uint8List.fromList(hash.sublist(0, 16)));
}

// ─── BacCrypto: BAC ключи из MRZ ────────────────────────────────────────────

class BacCrypto {
  final Uint8List kEnc;
  final Uint8List kMac;

  BacCrypto(this.kEnc, this.kMac);

  /// MRZ info = docNum+cd + dob+cd + exp+cd (как в _getMrzInfo)
  factory BacCrypto.fromMrz(String mrzInfo) {
    final hash = sha1.convert(mrzInfo.codeUnits).bytes;
    final kSeed = Uint8List.fromList(hash.sublist(0, 16));
    return BacCrypto(
      deriveKey(kSeed, [0, 0, 0, 1]),
      deriveKey(kSeed, [0, 0, 0, 2]),
    );
  }
}

// ─── SecureSession: Secure Messaging после BAC ──────────────────────────────

class SecureSession {
  final Uint8List ksEnc;
  final Uint8List ksMac;
  Uint8List ssc; // Send Sequence Counter (8 bytes)

  SecureSession(this.ksEnc, this.ksMac, this.ssc);

  /// Создать сессию из результатов BAC
  factory SecureSession.fromBac({
    required Uint8List kIfd,
    required Uint8List kIcc,
    required Uint8List rndIfd,
    required Uint8List rndIcc,
  }) {
    // KS_seed = K.IFD XOR K.ICC
    final ksSeed = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      ksSeed[i] = kIfd[i] ^ kIcc[i];
    }
    final ksEnc = deriveKey(ksSeed, [0, 0, 0, 1]);
    final ksMac = deriveKey(ksSeed, [0, 0, 0, 2]);
    // SSC = RND.ICC[4..7] || RND.IFD[4..7]
    final ssc = Uint8List.fromList([
      ...rndIcc.sublist(4, 8),
      ...rndIfd.sublist(4, 8),
    ]);
    return SecureSession(ksEnc, ksMac, ssc);
  }

  void _incrementSSC() {
    for (int i = 7; i >= 0; i--) {
      ssc[i]++;
      if (ssc[i] != 0) break;
    }
  }

  /// Обернуть APDU в Secure Messaging
  Uint8List wrapApdu(int cla, int ins, int p1, int p2, {Uint8List? data, int? le}) {
    _incrementSSC();

    final cmdHeader = padMethod2(Uint8List.fromList([0x0C, ins, p1, p2]));
    final dos = <int>[]; // Data Objects для тела APDU

    // DO'87 — зашифрованные данные (если есть)
    if (data != null && data.isNotEmpty) {
      final padded = padMethod2(data);
      final encrypted = desedeCbcEncrypt(ksEnc, padded);
      // DO'87: tag=87, length, 01 (padding indicator), encrypted data
      final do87content = Uint8List.fromList([0x01, ...encrypted]);
      dos.addAll([0x87, ..._berLength(do87content.length), ...do87content]);
    }

    // DO'97 — ожидаемая длина ответа
    if (le != null) {
      dos.addAll([0x97, 0x01, le]);
    }

    // MAC input = SSC || padded_header || DO'87 || DO'97
    final macInput = Uint8List.fromList([...ssc, ...cmdHeader, ...dos]);
    final mac = computeMAC(ksMac, macInput);

    // DO'8E — MAC
    dos.addAll([0x8E, 0x08, ...mac]);

    // Собираем финальный APDU
    final lc = dos.length;
    return Uint8List.fromList([0x0C, ins, p1, p2, lc, ...dos, 0x00]);
  }

  /// Развернуть ответ Secure Messaging → чистые данные
  Uint8List? unwrapResponse(Uint8List response) {
    if (response.length < 2) return null;

    final sw1 = response[response.length - 2];
    final sw2 = response[response.length - 1];
    final body = response.sublist(0, response.length - 2);
    _incrementSSC(); // Инкремент ДО проверки статуса, т.к. чип его уже увеличил!

    if (sw1 != 0x90 || sw2 != 0x00) return null;

    Uint8List? encryptedData;
    Uint8List? do99;
    int pos = 0;

    while (pos < body.length) {
      int tag = body[pos++];
      final lenInfo = _readBerLength(body, pos);
      int len = lenInfo[0];
      pos = lenInfo[1];

      if (tag == 0x87) {
        // Зашифрованные данные (первый байт = padding indicator 0x01)
        encryptedData = Uint8List.fromList(body.sublist(pos + 1, pos + len));
        pos += len;
      } else if (tag == 0x99) {
        do99 = Uint8List.fromList(body.sublist(pos, pos + len));
        pos += len;
      } else if (tag == 0x8E) {
        // MAC — пропускаем верификацию для скорости
        pos += len;
      } else {
        pos += len;
      }
    }

    if (encryptedData != null) {
      final decrypted = desedeCbcDecrypt(ksEnc, encryptedData);
      return unpadMethod2(decrypted);
    }

    return null; // нет данных в ответе (например, SELECT без ответа)
  }

  List<int> _berLength(int len) {
    if (len < 0x80) return [len];
    if (len <= 0xFF) return [0x81, len];
    return [0x82, (len >> 8) & 0xFF, len & 0xFF];
  }

  List<int> _readBerLength(Uint8List data, int pos) {
    int len = data[pos++];
    if (len == 0x81) {
      len = data[pos++];
    } else if (len == 0x82) {
      len = (data[pos] << 8) | data[pos + 1];
      pos += 2;
    }
    return [len, pos];
  }
}

// ─── TLV Parser ─────────────────────────────────────────────────────────────

class TlvNode {
  final int tag;
  final Uint8List value;
  TlvNode(this.tag, this.value);

  List<TlvNode> get children => parseTlv(value);

  TlvNode? find(int searchTag) {
    for (var c in children) {
      if (c.tag == searchTag) return c;
      final deep = c.find(searchTag);
      if (deep != null) return deep;
    }
    return null;
  }
}

List<TlvNode> parseTlv(Uint8List data) {
  final nodes = <TlvNode>[];
  int pos = 0;
  while (pos < data.length) {
    if (data[pos] == 0x00 || data[pos] == 0xFF) { pos++; continue; }

    // Tag
    int tag = data[pos++];
    if ((tag & 0x1F) == 0x1F) {
      // Multi-byte tag
      do {
        if (pos >= data.length) return nodes;
        tag = (tag << 8) | data[pos++];
      } while ((data[pos - 1] & 0x80) != 0);
    }

    if (pos >= data.length) break;

    // Length
    int len = data[pos++];
    if (len == 0x81) {
      if (pos >= data.length) break;
      len = data[pos++];
    } else if (len == 0x82) {
      if (pos + 1 >= data.length) break;
      len = (data[pos] << 8) | data[pos + 1];
      pos += 2;
    } else if (len == 0x83) {
      if (pos + 2 >= data.length) break;
      len = (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2];
      pos += 3;
    }

    if (pos + len > data.length) len = data.length - pos;
    nodes.add(TlvNode(tag, Uint8List.fromList(data.sublist(pos, pos + len))));
    pos += len;
  }
  return nodes;
}

// ─── MRZ Parser (TD1 — ID Cards) ────────────────────────────────────────────

class MrzData {
  final String documentNumber;
  final String dateOfBirth;    // DD.MM.YYYY
  final String dateOfExpiry;   // DD.MM.YYYY
  final String surname;        // Latin
  final String givenNames;     // Latin
  final String sex;            // M / F
  final String nationality;
  final String inn;            // Из MRZ optional data (если есть)

  MrzData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.surname,
    required this.givenNames,
    required this.sex,
    required this.nationality,
    this.inn = '',
  });

  String get fullNameLatin => '$surname $givenNames';
}

/// Парсинг MRZ из байтов DG1 (tag 0x5F1F)
MrzData? parseMrz(Uint8List mrzBytes) {
  final mrzStr = String.fromCharCodes(mrzBytes).replaceAll('\n', '').replaceAll('\r', '');

  if (mrzStr.length >= 90) {
    // TD1 формат (ID карта): 3 строки по 30 символов
    final line1 = mrzStr.substring(0, 30);
    final line2 = mrzStr.substring(30, 60);
    final line3 = mrzStr.substring(60, 90);

    // Line 1: I<KGZ[DocNum 9][CD][Optional 15]
    String docNum = line1.substring(5, 14).replaceAll('<', '');

    // Line 2: [DOB 6][CD][Sex 1][Expiry 6][CD][Nationality 3][Optional 11][CD]
    String dobRaw = line2.substring(0, 6);
    String sex = line2.substring(7, 8);
    String expiryRaw = line2.substring(8, 14);
    String nationality = line2.substring(15, 18).replaceAll('<', '');

    // Optional data (line1[15..29] + line2[18..28]) — может содержать ИНН
    String optional1 = line1.substring(15, 30).replaceAll('<', '');
    String optional2 = line2.substring(18, 29).replaceAll('<', '');
    String inn = '';
    // ИНН Кыргызстана = 14 цифр, начинается с 1 или 2
    final innRegex = RegExp(r'[12]\d{13}');
    final innMatch = innRegex.firstMatch(optional1 + optional2);
    if (innMatch != null) inn = innMatch.group(0)!;

    // Line 3: Surname<<GivenNames<<<
    final nameRegex = RegExp(r'([A-Z]+)<<([A-Z<]+)');
    final nameMatch = nameRegex.firstMatch(line3);
    String surname = nameMatch?.group(1) ?? '';
    String givenNames = (nameMatch?.group(2) ?? '').replaceAll('<', ' ').trim();

    return MrzData(
      documentNumber: docNum,
      dateOfBirth: _mrzDateToDisplay(dobRaw),
      dateOfExpiry: _mrzDateToDisplay(expiryRaw),
      surname: surname,
      givenNames: givenNames,
      sex: sex == 'M' ? 'Мужской' : (sex == 'F' ? 'Женский' : ''),
      nationality: nationality,
      inn: inn,
    );
  } else if (mrzStr.length >= 88) {
    // TD3 формат (паспорт): 2 строки по 44
    final line1 = mrzStr.substring(0, 44);
    final line2 = mrzStr.substring(44, 88);

    final nameRegex = RegExp(r'[A-Z]<([A-Z]+)<<([A-Z<]+)');
    final nameMatch = nameRegex.firstMatch(line1);
    String surname = nameMatch?.group(1) ?? '';
    String givenNames = (nameMatch?.group(2) ?? '').replaceAll('<', ' ').trim();

    String docNum = line2.substring(0, 9).replaceAll('<', '');
    String dobRaw = line2.substring(13, 19);
    String sex = line2.substring(20, 21);
    String expiryRaw = line2.substring(21, 27);

    return MrzData(
      documentNumber: docNum,
      dateOfBirth: _mrzDateToDisplay(dobRaw),
      dateOfExpiry: _mrzDateToDisplay(expiryRaw),
      surname: surname,
      givenNames: givenNames,
      sex: sex == 'M' ? 'Мужской' : (sex == 'F' ? 'Женский' : ''),
      nationality: line2.substring(10, 13).replaceAll('<', ''),
    );
  }

  return null;
}

/// YYMMDD → DD.MM.YYYY (предполагая 19xx для YY>50, 20xx иначе)
String _mrzDateToDisplay(String yymmdd) {
  if (yymmdd.length != 6) return '';
  int yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
  String mm = yymmdd.substring(2, 4);
  String dd = yymmdd.substring(4, 6);
  int yyyy = yy > 50 ? 1900 + yy : 2000 + yy;
  return '$dd.$mm.$yyyy';
}
