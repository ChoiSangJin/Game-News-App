import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
import '../models/story.dart';

class FetchResult {
  const FetchResult(this.stories, this.warnings);
  final List<Story> stories;
  final List<String> warnings;
}

abstract class FeedSource {
  Future<FetchResult> fetch(
    String rawgKey, {
    GamePlatform? platform,
    bool calendar = false,
  });
}

class PublicFeeds implements FeedSource {
  PublicFeeds(this.client, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final http.Client client;
  final DateTime Function() clock;
  static final feeds = {
    'PC Gamer': Uri.parse('https://www.pcgamer.com/rss/'),
    'GameSpot': Uri.parse('https://www.gamespot.com/feeds/mashup/'),
  };
  Future<String> _get(Uri uri) async {
    final response = await client
        .get(
          uri,
          headers: {
            'User-Agent': 'GameBrief/1.0 (personal RSS reader)',
            'Accept': 'application/rss+xml, application/json, text/xml',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 429) throw StateError('요청 한도 도달. 나중에 다시 시도하세요.');
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<void> validateKey(String key) async {
    if (key.isEmpty) throw StateError('RAWG API 키를 입력하세요.');
    final response = await client
        .get(
          Uri.https('api.rawg.io', '/api/games', {
            'key': key,
            'page_size': '1',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('RAWG API 키가 올바르지 않거나 권한이 없습니다.');
    }
    if (response.statusCode == 429) {
      throw StateError('RAWG 요청 한도에 도달했습니다. 잠시 후 다시 확인하세요.');
    }
    if (response.statusCode != 200) {
      throw StateError('RAWG 연결 실패 (HTTP ${response.statusCode}).');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['results'] is! List) {
      throw StateError('RAWG 응답을 확인할 수 없습니다.');
    }
  }

  @override
  Future<FetchResult> fetch(
    String rawgKey, {
    GamePlatform? platform,
    bool calendar = false,
  }) async {
    final all = <Story>[];
    final warnings = <String>[];
    // One request per source; no automatic retry loop or scraping.
    for (final entry
        in (calendar ? <MapEntry<String, Uri>>[] : feeds.entries)) {
      try {
        all.addAll(parseRss(await _get(entry.value), entry.key));
      } catch (_) {
        warnings.add('${entry.key} 피드를 불러오지 못했습니다.');
      }
    }
    if (calendar && rawgKey.isNotEmpty) {
      try {
        final now = clock();
        final fmt = DateFormat('yyyy-MM-dd');
        final uri = Uri.https('api.rawg.io', '/api/games', {
          'key': rawgKey,
          'dates':
              '${fmt.format(now)},${fmt.format(now.add(const Duration(days: 180)))}',
          'ordering': 'released',
          'page_size': '40',
        });
        all.addAll(parseRawg(await _get(uri)));
      } catch (_) {
        warnings.add('RAWG 일정을 불러오지 못했습니다. API 키와 요청 한도를 확인하세요.');
      }
    }
    if (all.isEmpty && warnings.isNotEmpty) {
      throw StateError('피드를 불러오지 못했습니다. 연결을 확인하고 다시 시도하세요.');
    }
    final unique = {for (final s in all) s.id: s};
    return FetchResult(
      unique.values
          .where(
            (s) => calendar
                ? s.isEvent
                : platform == null || s.platforms.contains(platform),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
      warnings,
    );
  }
}

String plainText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<Story> parseRss(String xml, String source) {
  final doc = XmlDocument.parse(xml);
  final result = <Story>[];
  for (final item in doc.findAllElements('item').take(40)) {
    String field(String name) => item.getElement(name)?.innerText.trim() ?? '';
    final link = field('link');
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
    final title = plainText(field('title'));
    if (title.isEmpty) continue;
    DateTime? date;
    date = parseFeedDate(field('pubDate'));
    if (date == null) continue;
    final body = plainText(field('description'));
    final categories = item
        .findElements('category')
        .map((c) => c.innerText)
        .join(' ');
    result.add(
      Story(
        id: link,
        title: title,
        body: body,
        source: source,
        url: link,
        date: date,
        platforms: classifyPlatforms('$title $body $categories'),
      ),
    );
  }
  return result;
}

List<Story> parseRawg(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return (j['results'] as List)
      .where((g) => g['released'] != null && g['tba'] != true)
      .map((g) {
        final names = (g['platforms'] as List? ?? [])
            .map((p) => p['platform']['name'])
            .join(' ');
        return Story(
          id: 'rawg:${g['id']}',
          title: g['name'] as String,
          body: '발매 예정 · $names\n일정은 변경될 수 있습니다. RAWG에서 최신 정보를 확인하세요.',
          source: 'RAWG',
          url: 'https://rawg.io/games/${g['slug']}',
          date: DateTime.parse(g['released'] as String),
          platforms: classifyPlatforms(names),
          isEvent: true,
        );
      })
      .toList();
}

DateTime? parseFeedDate(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}:\d{2}:\d{2}) (GMT|UT|[+-]\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  try {
    var date = DateFormat(
      'd MMM yyyy HH:mm:ss',
      'en_US',
    ).parseStrict('${match[1]} ${match[2]} ${match[3]} ${match[4]}', true);
    final zone = match[5]!;
    if (zone.startsWith('+') || zone.startsWith('-')) {
      final hours = int.parse(zone.substring(1, 3));
      final minutes = int.parse(zone.substring(3, 5));
      if (hours > 23 || minutes > 59) return null;
      date = date.subtract(
        Duration(
          minutes: (hours * 60 + minutes) * (zone.startsWith('-') ? -1 : 1),
        ),
      );
    }
    return date;
  } catch (_) {
    return null;
  }
}
