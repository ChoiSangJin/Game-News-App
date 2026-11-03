import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story.dart';

class FeedCache {
  FeedCache(this.prefs, {this.namespace = key});
  final String namespace;
  final SharedPreferences prefs;
  static const ttl = Duration(hours: 12);
  static const key = 'feed_cache_v1';
  List<Story> stories = [];
  DateTime? lastFetch;
  bool invalidated = false;
  bool isFresh(DateTime now) {
    final stamp = lastFetch;
    if (stamp == null || invalidated) return false;
    final age = now.difference(stamp);
    return !age.isNegative && age < ttl;
  }

  void load() {
    try {
      final raw = prefs.getString(namespace);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stories = (j['stories'] as List)
          .map((s) => Story.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
      lastFetch = j['last_fetch_time'] == null
          ? null
          : DateTime.parse(j['last_fetch_time'] as String);
      invalidated = j['invalidated'] == true;
    } catch (_) {
      stories = [];
      lastFetch = null;
      invalidated = true;
    }
  }

  Future<void> save(List<Story> values, DateTime stamp) async {
    await prefs.setString(
      namespace,
      jsonEncode({
        'last_fetch_time': stamp.toIso8601String(),
        'stories': values.map((s) => s.toJson()).toList(),
        'invalidated': false,
      }),
    );
    stories = values;
    lastFetch = stamp;
    invalidated = false;
  }

  Future<void> invalidate() async {
    await prefs.setString(
      namespace,
      jsonEncode({
        'last_fetch_time': lastFetch?.toIso8601String(),
        'stories': stories.map((s) => s.toJson()).toList(),
        'invalidated': true,
      }),
    );
    invalidated = true;
  }
}
