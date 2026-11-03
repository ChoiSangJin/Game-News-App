enum GamePlatform { pc, ps5, nintendo, mobile }

class Story {
  const Story({required this.id, required this.title, required this.body,
    required this.source, required this.url, required this.date,
    this.platforms = const [], this.isEvent = false, this.titleKo});
  final String id, title, body, source, url;
  final DateTime date;
  final List<GamePlatform> platforms;
  final bool isEvent;
  final String? titleKo;

  Story translated(String ko) => Story(id: id, title: title, body: body,
    source: source, url: url, date: date, platforms: platforms,
    isEvent: isEvent, titleKo: ko);

  Map<String, dynamic> toJson() => {'id': id, 'title_en': title,
    'title_ko': titleKo, 'body': body, 'source': source, 'url': url,
    'date': date.toIso8601String(), 'platforms': platforms.map((p) => p.name).toList(),
    'isEvent': isEvent};

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: j['id'] as String, title: j['title_en'] as String,
    titleKo: j['title_ko'] as String?, body: j['body'] as String,
    source: j['source'] as String, url: j['url'] as String,
    date: DateTime.parse(j['date'] as String), isEvent: j['isEvent'] == true,
    platforms: (j['platforms'] as List).map((p) => GamePlatform.values.byName(p as String)).toList());
}

List<GamePlatform> classifyPlatforms(String text) {
  final t = text.toLowerCase();
  return [
    if (RegExp(r'\b(pc|steam|windows|linux)\b').hasMatch(t)) GamePlatform.pc,
    if (RegExp(r'\b(ps5|playstation|ps plus)\b').hasMatch(t)) GamePlatform.ps5,
    if (RegExp(r'\b(nintendo|switch)\b').hasMatch(t)) GamePlatform.nintendo,
    if (RegExp(r'\b(mobile|android|ios|iphone|ipad)\b').hasMatch(t)) GamePlatform.mobile,
  ];
}
