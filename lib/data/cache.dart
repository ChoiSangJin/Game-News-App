import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story.dart';

class FeedCache {
  FeedCache(this.prefs);
  final SharedPreferences prefs;
  static const ttl = Duration(hours: 12);
  static const key = 'feed_cache_v1';
  List<Story> stories = [];
  DateTime? lastFetch;
  bool isFresh(DateTime now) {
    final stamp = lastFetch;
    if (stamp == null) return false;
    final age = now.difference(stamp);
    return !age.isNegative && age < ttl;
  }
  void load() {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stories = (j['stories'] as List).map((s) => Story.fromJson(Map<String, dynamic>.from(s as Map))).toList();
      lastFetch = DateTime.parse(j['last_fetch_time'] as String);
    } catch (_) { stories = []; lastFetch = null; }
  }
  Future<void> save(List<Story> values, DateTime stamp) async {
    await prefs.setString(key, jsonEncode({'last_fetch_time': stamp.toIso8601String(),
      'stories': values.map((s) => s.toJson()).toList()}));
    stories = values;
    lastFetch = stamp;
  }
  Future<void> invalidate() async {
    await save(stories, DateTime.fromMillisecondsSinceEpoch(0));
  }
}
