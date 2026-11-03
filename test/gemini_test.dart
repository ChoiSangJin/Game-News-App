import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_news_app/data/translation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  http.Response models() => http.Response(
    jsonEncode({
      'models': [
        {
          'name': 'models/gemini-3.8-flash',
          'supportedGenerationMethods': ['generateContent'],
        },
        {
          'name': 'models/gemini-4-argon',
          'supportedGenerationMethods': ['generateContent'],
        },
        {
          'name': 'models/gemini-3.9-flash-preview',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    }),
    200,
  );
  http.Response translated(List<String> texts) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': jsonEncode(texts)},
            ],
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  test('no key never sends a request', () async {
    var calls = 0;
    final t = GeminiTranslator(
      await prefs(),
      MockClient((r) async {
        calls++;
        return models();
      }),
    );
    await expectLater(t.translate('news'), throwsStateError);
    expect(calls, 0);
  });
  test(
    'batch titles, secure header, one daily model check, cached reuse and no body prefetch',
    () async {
      var checks = 0, generations = 0;
      final t = GeminiTranslator(
        await prefs(),
        MockClient((r) async {
          expect(r.url.queryParameters.containsKey('key'), isFalse);
          expect(r.headers['x-goog-api-key'], 'fixture-key');
          if (r.method == 'GET') {
            checks++;
            return models();
          }
          generations++;
          final body = jsonDecode(r.body);
          expect(jsonDecode(body['contents'][0]['parts'][0]['text']), [
            'Title one',
            'Title two',
          ]);
          expect(body['generationConfig']['maxOutputTokens'], 8192);
          return translated(['제목 하나', '제목 둘']);
        }),
      )..apiKey = 'fixture-key';
      expect(await t.translateTitles(['Title one', 'Title two']), [
        '제목 하나',
        '제목 둘',
      ]);
      expect(await t.translate('Title one'), '제목 하나');
      expect(checks, 1);
      expect(generations, 1);
      expect(t.availableModels, ['gemini-3.8-flash']);
    },
  );
  test('429 stops repeated requests without retries', () async {
    var calls = 0;
    final t = GeminiTranslator(
      await prefs(),
      MockClient((r) async {
        if (r.method == 'GET') return models();
        calls++;
        return http.Response('{}', 429);
      }),
    )..apiKey = 'fixture-key';
    await expectLater(t.translate('Title'), throwsStateError);
    await expectLater(t.translate('Title'), throwsStateError);
    expect(calls, 1);
  });
  test('malformed batch is never cached', () async {
    var calls = 0;
    final t = GeminiTranslator(
      await prefs(),
      MockClient((r) async {
        if (r.method == 'GET') return models();
        calls++;
        return translated(['한 개']);
      }),
    )..apiKey = 'fixture-key';
    await expectLater(t.translateTitles(['one', 'two']), throwsStateError);
    await expectLater(t.translateTitles(['one', 'two']), throwsStateError);
    expect(calls, 2);
  });
  test(
    'retired model prevents billable generation and asks user to choose',
    () async {
      var calls = 0;
      final t = GeminiTranslator(
        await prefs(),
        MockClient((r) async {
          if (r.method == 'GET') return http.Response('{"models":[]}', 200);
          calls++;
          return translated(['번역']);
        }),
      )..apiKey = 'fixture-key';
      await expectLater(t.translate('Title'), throwsStateError);
      expect(calls, 0);
    },
  );
}
