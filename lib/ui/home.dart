import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/story.dart';
import '../state/app_state.dart';
import 'detail.dart';
import 'settings.dart';
import 'add_event.dart';

const platformLabels = {GamePlatform.pc: 'PC', GamePlatform.ps5: 'PS5',
  GamePlatform.nintendo: 'Nintendo', GamePlatform.mobile: 'Mobile'};
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int tab = 0;
  bool korean = false;
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppState>().refresh();
  }
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = tab == 0 ? app.news : app.eventsOn(selected);
    return Scaffold(
      appBar: AppBar(title: const Text('GAME BRIEF', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        actions: [TextButton(onPressed: () => setState(() => korean = !korean),
          child: Text(korean ? '가 / A' : 'A / 가')),
          IconButton(tooltip: '설정', icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SettingsPage()))) ]),
      body: Column(children: [
        if (app.busy) const LinearProgressIndicator(minHeight: 2),
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: Alignment.centerLeft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tab == 0 ? '게임의 다음 소식' : '다가오는 플레이', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(app.cache.lastFetch == null ? 'RSS 뉴스 · RAWG 발매 일정' : '업데이트 ${DateFormat('MM.dd HH:mm').format(app.cache.lastFetch!.toLocal())} · 12시간 캐시',
              style: Theme.of(context).textTheme.bodySmall),
          ]))),
        if (app.error != null || app.warnings.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text([if (app.error != null) app.error!, ...app.warnings].join('\n'),
              style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (tab == 0) SingleChildScrollView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('전체'),
              selected: app.platform == null, onSelected: (_) => app.selectPlatform(null))),
            for (final entry in platformLabels.entries) Padding(padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: Text(entry.value), selected: app.platform == entry.key,
                onSelected: (_) => app.selectPlatform(entry.key))),
          ])),
        Expanded(child: RefreshIndicator(onRefresh: () => app.refresh(force: true),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(), children: [
            if (tab == 1) ...[
              _calendar(app),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                child: Text(DateFormat('M월 d일 일정').format(selected), style: Theme.of(context).textTheme.titleLarge)),
              if (app.rawgKey.isEmpty) const InfoCard(icon: Icons.key_outlined,
                title: '발매 일정 연결', body: '설정에서 무료 RAWG API 키를 입력하면 앞으로 180일 중 최대 40개 발매 일정을 조회합니다.'),
              const Padding(padding: EdgeInsets.all(8), child: Text('RAWG 발매일 · 쇼케이스·게임쇼는 공식 일정을 확인해 직접 추가하세요.')),
            ],
            if (items.isEmpty && !app.busy) InfoCard(icon: tab == 0 ? Icons.rss_feed : Icons.event_available,
              title: tab == 0 ? '표시할 뉴스가 없습니다' : '이 날짜에는 일정이 없습니다',
              body: tab == 0 ? '다른 플랫폼을 선택하거나 아래로 당겨 새로고침하세요.' : '표시된 점이 있는 날짜를 선택하세요.'),
            for (final story in items) StoryCard(story: story, korean: korean),
          ]))),
      ]),
      floatingActionButton: tab == 1 ? FloatingActionButton.extended(onPressed: () => addPersonalEvent(context, selected), icon: const Icon(Icons.add), label: const Text('일정 추가')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) {
        setState(() => tab = value); app.refresh();
      }, destinations: const [NavigationDestination(icon: Icon(Icons.newspaper_outlined), label: '뉴스 피드'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '이벤트 달력')]),
    );
  }
  Widget _calendar(AppState app) {
    final firstOffset = DateTime(month.year, month.month).weekday % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(tooltip: '이전 달', icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
        Text(DateFormat('yyyy년 M월').format(month), style: Theme.of(context).textTheme.titleMedium),
        IconButton(tooltip: '다음 달', icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
      ]),
      Row(children: [for (final label in ['일','월','화','수','목','금','토']) Expanded(child: Center(child: Text(label)))]),
      const SizedBox(height: 8),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
        itemCount: firstOffset + days, itemBuilder: (context, index) {
          if (index < firstOffset) return const SizedBox.shrink();
          final day = DateTime(month.year, month.month, index - firstOffset + 1);
          final active = DateUtils.isSameDay(day, selected);
          return InkWell(borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => selected = day),
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: active ? Theme.of(context).colorScheme.primaryContainer : null),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${day.day}'),
                if (app.hasEvent(day)) const Text('•', style: TextStyle(color: Color(0xFF99EDBB), height: .7)),
              ])));
        }),
    ])));
  }
}
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Icon(icon, size: 32), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8), Text(body, textAlign: TextAlign.center),
  ])));
}
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story, required this.korean});
  final Story story;
  final bool korean;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(vertical: 6),
    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => DetailPage(story: story))),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${story.source.toUpperCase()}  ·  ${DateFormat('MM.dd').format(story.date.toLocal())}',
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 10), Text(korean ? story.titleKo ?? story.title : story.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10), Text(story.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (story.platforms.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(story.platforms.map((p) => platformLabels[p]).join('  /  '), style: Theme.of(context).textTheme.labelSmall)),
      ]))));
}
