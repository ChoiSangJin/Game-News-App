import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_news_app/data/cache.dart';
import 'package:game_news_app/data/sources.dart';
import 'package:game_news_app/data/translation.dart';
import 'package:game_news_app/models/story.dart';
import 'package:game_news_app/state/app_state.dart';

const rss = '''<rss><channel><item><title>New PS5 &amp; PC game</title>
<link>https://example.com/game</link><pubDate>Tue, 03 Nov 2026 09:00:00 +0900</pubDate>
<description><![CDATA[<p>Steam release</p>]]></description></item>
<item><title>Unsafe</title><link>javascript:bad()</link></item></channel></rss>''';
Story sample({String id = 'one', bool event = false}) => Story(id: id,
  title: 'PC launch', body: 'Summary body', source: 'Fixture',
  url: 'https://example.com/$id', date: DateTime(2026,11,3),
  platforms: [GamePlatform.pc], isEvent: event);
class FakeSource implements FeedSource {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  List<String> warnings = [];
  @override
  Future<FetchResult> fetch(String key) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('offline');
    return FetchResult([sample()], warnings);
  }
}
class FakeTranslator implements Translator {
  final texts = <String>[];
  @override
  Future<String> translate(String text) async { texts.add(text); return '번역: $text'; }
  @override
  Future<void> close() async {}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeedCache cache;
  late FakeSource source;
  late FakeTranslator translator;
  late AppState app;
  var now = DateTime.utc(2026,11,3);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = FeedCache(await SharedPreferences.getInstance());
    source = FakeSource(); translator = FakeTranslator();
    now = DateTime.utc(2026,11,3);
    app = AppState(cache, source, translator, clock: () => now);
  });
  test('RSS parsing sanitizes summary, validates link and honors offset', () {
    final values = parseRss(rss, 'Test');
    expect(values, hasLength(1));
    expect(values.single.title, 'New PS5 & PC game');
    expect(values.single.body, 'Steam release');
    expect(values.single.date, DateTime.utc(2026,11,3));
    expect(values.single.platforms, containsAll([GamePlatform.pc, GamePlatform.ps5]));
    expect(parseFeedDate('garbage'), isNull);
    expect(parseFeedDate('Tue, 03 Nov 2026 00:00:00 GMT'), DateTime.utc(2026,11,3));
  });
  test('cache is fresh below 12h, expired at 12h, rejects clock reversal', () async {
    await cache.save([sample()], now);
    expect(cache.isFresh(now.add(const Duration(hours: 12) - Duration(microseconds: 1))), isTrue);
    expect(cache.isFresh(now.add(const Duration(hours: 12))), isFalse);
    expect(cache.isFresh(now.subtract(const Duration(seconds: 1))), isFalse);
    final restored = FeedCache(cache.prefs)..load();
    expect(restored.stories.single.toJson(), sample().toJson());
  });
  test('valid cache and local platform changes never fetch or translate', () async {
    await cache.save([sample()], now);
    await app.refresh();
    app.selectPlatform(GamePlatform.ps5);
    expect(app.news, isEmpty);
    app.selectPlatform(GamePlatform.pc);
    expect(app.news, hasLength(1));
    expect(source.calls, 0); expect(translator.texts, isEmpty);
  });
  test('fetch translates titles only; TTL prevents duplicate fetch', () async {
    await app.refresh();
    expect(translator.texts, ['PC launch']);
    expect(cache.stories.single.titleKo, '번역: PC launch');
    await app.refresh();
    expect(source.calls, 1);
    now = now.add(const Duration(hours: 12));
    await app.refresh();
    expect(source.calls, 2);
    expect(translator.texts, hasLength(1));
  });
  test('overlapping refreshes share one network request', () async {
    source.gate = Completer<void>();
    final first = app.refresh(); final second = app.refresh(force: true);
    expect(source.calls, 1);
    source.gate!.complete();
    await Future.wait([first,second]);
    expect(app.busy, isFalse);
  });
  test('manual refresh invalidates TTL; failure preserves offline data on disk', () async {
    await cache.save([sample()], now);
    source.fail = true;
    await app.refresh(force: true);
    expect(app.error, isNotNull); expect(cache.stories, hasLength(1));
    expect(cache.isFresh(now), isFalse);
    final restored = FeedCache(cache.prefs)..load();
    expect(restored.stories, hasLength(1)); expect(restored.isFresh(now), isFalse);
    await app.refresh(force: true);
    expect(source.calls, 1);
    now = now.add(const Duration(minutes: 1)); source.fail = false;
    await app.refresh(force: true);
    expect(source.calls, 2); expect(cache.isFresh(now), isTrue);
  });
  test('partial success preserves stale data and remains eligible for retry', () async {
    await cache.save([sample(id:'old')], now.subtract(const Duration(days:1)));
    source.warnings = ['Feed unavailable'];
    await app.refresh();
    expect(cache.stories.map((s) => s.id), containsAll(['old','one']));
    expect(cache.isFresh(now), isFalse);
    expect(app.warnings, isNotEmpty);
  });
  test('personal schedules persist separately from remote refresh', () async {
    await app.addEvent(sample(id:'personal:1',event:true));
    await app.refresh();
    expect(app.eventsOn(DateTime(2026,11,3)), hasLength(1));
    final restored = AppState(FeedCache(cache.prefs), source, translator);
    expect(restored.eventsOn(DateTime(2026,11,3)), hasLength(1));
    await restored.removeEvent('personal:1');
    expect(restored.eventsOn(DateTime(2026,11,3)), isEmpty);
  });
  test('RAWG maps platforms and skips unconfirmed dates', () {
    final values = parseRawg('{"results":[{"id":42,"name":"Game","slug":"game","released":"2026-12-01","tba":false,"platforms":[{"platform":{"name":"PlayStation 5"}}]},{"released":null}]}');
    expect(values.single.isEvent, isTrue);
    expect(values.single.platforms, contains(GamePlatform.ps5));
  });
  test('corrupt cache falls back safely', () async {
    await cache.prefs.setString(FeedCache.key, 'not-json');
    cache.load();
    expect(cache.stories, isEmpty); expect(cache.lastFetch, isNull);
  });
}
