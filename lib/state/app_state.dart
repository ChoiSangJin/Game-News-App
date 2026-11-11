import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/cache.dart';
import '../data/sources.dart';
import '../data/translation.dart';
import '../models/story.dart';

class AppState extends ChangeNotifier {
  AppState(
    this.cache,
    this.source,
    this.translator, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    cache.load();
    try {
      final raw = cache.prefs.getString('personal_events_v1');
      if (raw != null) {
        personalEvents = (jsonDecode(raw) as List)
            .map((e) => Story.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      personalEvents = [];
    }
  }
  FeedCache cache;
  bool calendarSelected = false;
  int _selection = 0;
  final FeedSource source;
  final Translator translator;
  final DateTime Function() clock;
  List<Story> personalEvents = [];
  Future<void> addEvent(Story event) async {
    final next = [...personalEvents, event];
    await cache.prefs.setString(
      'personal_events_v1',
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    personalEvents = next;
    notifyListeners();
  }

  Future<void> removeEvent(String id) async {
    final next = personalEvents.where((e) => e.id != id).toList();
    await cache.prefs.setString(
      'personal_events_v1',
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    personalEvents = next;
    notifyListeners();
  }

  String rawgKey = '';
  GamePlatform? platform;
  bool busy = false;
  String? error;
  List<String> warnings = [];
  DateTime? _lastAttempt;
  static const cooldown = Duration(minutes: 1);
  Future<void>? _pending;
  List<Story> get news => cache.stories
      .where(
        (s) =>
            !s.isEvent && (platform != null && s.platforms.contains(platform)),
      )
      .toList();
  List<Story> eventsOn(DateTime day) => [...cache.stories, ...personalEvents]
      .where(
        (s) =>
            s.isEvent &&
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      )
      .toList();
  bool hasEvent(DateTime day) => eventsOn(day).isNotEmpty;
  Future<void> selectPlatform(GamePlatform? value) async {
    final ticket = ++_selection;
    platform = value;
    calendarSelected = false;
    error = null;
    cache = FeedCache(
      cache.prefs,
      namespace: 'feed_gemini_v1:${value?.name ?? "none"}',
    )..load();
    _lastAttempt = null;
    notifyListeners();
    await _pending;
    if (ticket == _selection && value != null) await refresh();
  }

  Future<void> selectCalendar() async {
    final ticket = ++_selection;
    calendarSelected = true;
    cache = FeedCache(cache.prefs, namespace: 'feed_gemini_v1:calendar')
      ..load();
    _lastAttempt = null;
    notifyListeners();
    await _pending;
    if (ticket == _selection) await refresh();
  }

  Future<void> refresh({bool force = false}) {
    if (platform == null && !calendarSelected) return Future.value();
    if (_pending != null) return _pending!;
    if (!force && cache.isFresh(clock())) return Future.value();
    if (_lastAttempt != null && clock().difference(_lastAttempt!) < cooldown) {
      if (force) {
        error = '요청 보호를 위해 1분 뒤 새로고침해 주세요.';
        notifyListeners();
      }
      return Future.value();
    }
    return _pending = _refresh(force).whenComplete(() => _pending = null);
  }

  Future<void> _refresh(bool force) async {
    final selectionTicket = _selection;
    final targetCache = cache;
    final selectedPlatform = platform;
    final selectedCalendar = calendarSelected;
    busy = true;
    error = null;
    warnings = [];
    _lastAttempt = clock();
    notifyListeners();
    try {
      // Keep the in-memory stale data on failure, but invalidate persistent TTL.
      if (force) await targetCache.invalidate();
      final result = await source.fetch(
        rawgKey,
        platform: selectedPlatform,
        calendar: selectedCalendar,
      );
      if (selectionTicket != _selection) return;
      final filtered = result.stories
          .where(
            (s) => selectedCalendar
                ? s.isEvent
                : !s.isEvent && s.platforms.contains(selectedPlatform),
          )
          .take(selectedCalendar ? 40 : 20)
          .toList();
      final values = <Story>[...filtered];
      var translationFailed = false;
      if (!selectedCalendar &&
          (translator is! GeminiTranslator ||
              (translator as GeminiTranslator).configured)) {
        try {
          final titles = await translator.translateTitles(
            filtered.map((s) => s.title).toList(),
          );
          for (var i = 0; i < values.length; i++) {
            values[i] = values[i].translated(titles[i]);
          }
        } catch (_) {
          translationFailed = true;
        }
      }
      warnings = [
        ...result.warnings,
        if (translationFailed)
          'Gemini 제목 번역에 실패했습니다. 원문을 표시합니다. 설정에서 키·모델·사용 한도를 확인하세요.',
      ];
      // Partial source failures retain old records and remain stale for retry.
      final merged = result.warnings.isEmpty
          ? values
          : {
              for (final s in targetCache.stories) s.id: s,
              for (final s in values) s.id: s,
            }.values.toList();
      merged.sort((a, b) => b.date.compareTo(a.date));
      await targetCache.save(merged, clock());
      if (result.warnings.isNotEmpty) await targetCache.invalidate();
    } catch (_) {
      error = '새 소식을 가져오지 못했습니다. 연결을 확인하고 다시 시도하세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> invalidateTranslationFeeds() async {
    for (final platform in GamePlatform.values) {
      final feed = FeedCache(
        cache.prefs,
        namespace: 'feed_gemini_v1:${platform.name}',
      )..load();
      await feed.invalidate();
    }
    if (!calendarSelected) await cache.invalidate();
    _lastAttempt = null;
    notifyListeners();
  }

  Future<void> updateRawgKey(String value) async {
    if (rawgKey == value) return;
    rawgKey = value;
    _lastAttempt = null;
    final calendarCache = FeedCache(
      cache.prefs,
      namespace: 'feed_gemini_v1:calendar',
    )..load();
    calendarCache.stories = [];
    await calendarCache.invalidate();
    if (calendarSelected) cache = calendarCache;
    notifyListeners();
  }

  Future<void> changeKey(String value) async {
    rawgKey = value.trim();
    // Remove schedules tied to a previous account and invalidate its TTL.
    cache.stories = cache.stories.where((s) => !s.isEvent).toList();
    await cache.invalidate();
    _lastAttempt = null;
    await refresh(force: true);
  }
}
