import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String normalizeApiKey(String input) {
  var value = input.trim();
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    value = value.substring(1, value.length - 1).trim();
  }
  if (value.isNotEmpty &&
      (RegExp(r'\s').hasMatch(value) || value.contains('://'))) {
    throw StateError('발급 페이지 주소 대신 API 키 문자열만 붙여넣어 주세요. 공백도 확인하세요.');
  }
  return value;
}

class ApiKeyStore {
  const ApiKeyStore();
  static const storage = FlutterSecureStorage();
  Future<String> save(String name, String input) async {
    final value = normalizeApiKey(input);
    if (value.isEmpty) {
      await storage.delete(key: name);
    } else {
      await storage.write(key: name, value: value);
    }
    if ((await storage.read(key: name) ?? '') != value) {
      throw StateError('기기 보안 저장소에 저장되지 않았습니다. 다시 시도하세요.');
    }
    return value;
  }
}
