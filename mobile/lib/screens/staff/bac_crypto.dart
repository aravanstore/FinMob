import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class BacCrypto {
  final Uint8List kEnc;
  final Uint8List kMac;

  BacCrypto(this.kEnc, this.kMac);

  /// Вычисляет ключи Kenc и Kmac из строки MRZ (24 символа)
  factory BacCrypto.fromMrz(String mrzInfo) {
    // 1. SHA-1 от MRZ строки
    final hash = sha1.convert(mrzInfo.codeUnits).bytes;
    final kSeed = Uint8List.fromList(hash.sublist(0, 16));

    // 2. Генерация Kenc (c=00000001)
    final kEnc = _deriveKey(kSeed, [0, 0, 0, 1]);
    // 3. Генерация Kmac (c=00000002)
    final kMac = _deriveKey(kSeed, [0, 0, 0, 2]);

    return BacCrypto(kEnc, kMac);
  }

  static Uint8List _deriveKey(Uint8List seed, List<int> counter) {
    final data = Uint8List.fromList([...seed, ...counter]);
    final hash = sha1.convert(data).bytes;
    final key = Uint8List.fromList(hash.sublist(0, 16));
    return _adjustParity(key);
  }

  static Uint8List _adjustParity(Uint8List key) {
    for (int i = 0; i < key.length; i++) {
      int b = key[i];
      int bitCount = 0;
      for (int j = 0; j < 8; j++) {
        if (((b >> j) & 0x01) == 1) bitCount++;
      }
      if (bitCount % 2 == 0) key[i] ^= 0x01;
    }
    return key;
  }

  /// Шифрование 3DES (TripleDES)
  Uint8List encrypt3DES(Uint8List key, Uint8List data) {
    final cipher = BlockCipher('DESede/ECB/NoPadding')
      ..init(true, KeyParameter(key));
    return cipher.process(data);
  }

  /// Вычисление MAC (ISO 9797-1 Algorithm 3)
  Uint8List computeMAC(Uint8List key, Uint8List data) {
    // Упрощенная реализация для теста
    final k1 = key.sublist(0, 8);
    final k2 = key.sublist(8, 16);
    
    final cipher = BlockCipher('DES/ECB/NoPadding');
    Uint8List block = Uint8List(8);
    
    // CBC с ключом k1
    for (int i = 0; i < data.length; i += 8) {
      for (int j = 0; j < 8; j++) block[j] ^= data[i + j];
      cipher.init(true, KeyParameter(k1));
      block = cipher.process(block);
    }
    
    // Финальная стадия Alg 3
    cipher.init(false, KeyParameter(k2));
    block = cipher.process(block);
    cipher.init(true, KeyParameter(k1));
    return cipher.process(block);
  }
}
