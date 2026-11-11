import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_news_app/data/api_keys.dart';
import 'package:game_news_app/data/cache.dart';
import 'package:game_news_app/data/sources.dart';
import 'package:game_news_app/data/translation.dart';
import 'package:game_news_app/main.dart';
import 'package:game_news_app/state/app_state.dart';
import 'core_test.dart' show FakeSource;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'keys are independently persisted and read back, quotes trimmed, URLs rejected',
    () async {
      const store = ApiKeyStore();
      expect(
        await store.save('gemini_key', '  "fixture-gemini"  '),
        'fixture-gemini',
      );
      await store.save('rawg_key', 'fixture-rawg');
      expect(
        await ApiKeyStore.storage.read(key: 'gemini_key'),
        'fixture-gemini',
      );
      expect(await ApiKeyStore.storage.read(key: 'rawg_key'), 'fixture-rawg');
      await store.save('gemini_key', '');
      expect(await ApiKeyStore.storage.read(key: 'rawg_key'), 'fixture-rawg');
      await expectLater(
        store.save('gemini_key', 'https://example.com/key'),
        throwsStateError,
      );
    },
  );
  test(
    'valid Gemini key with unavailable default uses supported Flash, not Pro',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final t = GeminiTranslator(
        prefs,
        MockClient(
          (r) async => http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-2.5-flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-2.5-pro',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-3-flash-preview',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
            }),
            200,
          ),
        ),
      )..apiKey = 'fixture';
      await t.checkModels();
      expect(t.model, 'gemini-2.5-flash');
      await t.configureKey('different-fixture');
      expect(prefs.getString('gemini_models_checked'), isNull);
      expect(t.availableModels, isEmpty);
    },
  );
  test(
    'RAWG key validation handles valid empty results and rejected key without RSS',
    () async {
      var calls = 0;
      final source = PublicFeeds(
        MockClient((r) async {
          calls++;
          expect(r.url.host, 'api.rawg.io');
          expect(r.url.queryParameters['page_size'], '1');
          return http.Response(
            r.url.queryParameters['key'] == 'valid' ? '{"results":[]}' : '{}',
            r.url.queryParameters['key'] == 'valid' ? 200 : 401,
          );
        }),
      );
      await source.validateKey('valid');
      await expectLater(source.validateKey('invalid'), throwsStateError);
      expect(calls, 2);
    },
  );
  testWidgets(
    'system bottom inset is reserved on home and settings; save needs no network',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      final prefs = await SharedPreferences.getInstance();
      var requests = 0;
      final t = GeminiTranslator(
        prefs,
        MockClient((r) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      final state = AppState(FeedCache(prefs), FakeSource(), t);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: const GameNewsApp()),
      );
      expect(
        tester.getRect(find.byType(Scaffold)).bottom,
        lessThanOrEqualTo(566),
      );
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(Scaffold).last).bottom,
        lessThanOrEqualTo(566),
      );
      await tester.enterText(find.byType(TextField).first, 'fixture-key');
      await tester.scrollUntilVisible(
        find.text('Gemini 키 저장'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Gemini 키 저장'));
      await tester.pumpAndSettle();
      expect(t.apiKey, 'fixture-key');
      expect(requests, 0);
      expect(await ApiKeyStore.storage.read(key: 'gemini_key'), 'fixture-key');
      expect(find.text('Gemini: 키 저장됨'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
