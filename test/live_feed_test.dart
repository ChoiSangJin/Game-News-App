import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:game_news_app/data/sources.dart';

void main() {
  test('public RSS endpoints return usable news without a key', () async {
    final client = http.Client();
    addTearDown(client.close);
    final result = await PublicFeeds(client).fetch('');
    expect(result.stories.where((s) => !s.isEvent), isNotEmpty);
    expect(result.stories.every((s) => Uri.parse(s.url).scheme == 'https'), isTrue);
    expect(result.stories.every((s) => s.title.trim().isNotEmpty), isTrue);
  }, skip: !const bool.fromEnvironment('LIVE_FEEDS'), timeout: const Timeout(Duration(minutes: 1)));
}
