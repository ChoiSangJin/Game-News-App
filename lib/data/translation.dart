import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class Translator {
  Future<String> translate(String text);
  Future<void> close();
}

// Translation runs on device. No article content is sent to a translation API.
class LocalTranslator implements Translator {
  LocalTranslator(this.prefs);
  final SharedPreferences prefs;
  final _manager = OnDeviceTranslatorModelManager();
  final _translator = OnDeviceTranslator(sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.korean);
  Future<void>? _ready;
  Future<void> _prepare() async {
    for (final code in ['en', 'ko']) {
      if (!await _manager.isModelDownloaded(code)) {
        final ok = await _manager.downloadModel(code, isWifiRequired: false).timeout(const Duration(minutes: 2));
        if (!ok) throw StateError('번역 모델을 다운로드할 수 없습니다. 연결 후 다시 시도하세요.');
      }
    }
  }
  @override
  Future<String> translate(String text) async {
    if (text.trim().isEmpty) return text;
    final key = 'translation_v1:$text';
    final saved = prefs.getString(key);
    if (saved != null) return saved;
    try {
      await (_ready ??= _prepare());
      final value = await _translator.translateText(text).timeout(const Duration(seconds: 20));
      await prefs.setString(key, value);
      return value;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }
  @override
  Future<void> close() => _translator.close();
}
