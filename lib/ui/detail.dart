import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/story.dart';
import '../state/app_state.dart';
import '../data/reminders.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.story});
  final Story story;
  @override
  State<DetailPage> createState() => _DetailPageState();
}
class _DetailPageState extends State<DetailPage> {
  bool korean = false, busy = false;
  String? bodyKo, titleKo, error;
  Future<void> toggle() async {
    if (korean) { setState(() => korean = false); return; }
    if (bodyKo != null) { setState(() => korean = true); return; }
    setState(() { busy = true; error = null; });
    try {
      final translator = context.read<AppState>().translator;
      final title = widget.story.titleKo ?? await translator.translate(widget.story.title);
      final body = await translator.translate(widget.story.body);
      if (!mounted) return;
      setState(() { titleKo = title; bodyKo = body; korean = true; });
    } catch (_) {
      if (mounted) setState(() => error = '번역 모델을 준비하지 못했습니다. 인터넷 연결 후 다시 시도하세요.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Scaffold(appBar: AppBar(title: Text(story.source), actions: [
      TextButton(onPressed: busy ? null : toggle, child: const Text('A / 가'))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(korean ? titleKo ?? story.titleKo ?? story.title : story.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12), Text('${story.source} · ${story.date.toLocal().toString().split(' ').first}'),
        const SizedBox(height: 24),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!)),
        SelectableText(korean ? bodyKo ?? story.body : story.body, style: const TextStyle(fontSize: 17, height: 1.7)),
        const SizedBox(height: 24),
        Text(story.isEvent ? '일정은 변경될 수 있습니다. 공식 출처를 확인하세요.' : 'RSS에서 제공한 요약입니다. 전체 기사는 출처에서 확인하세요.'),
        if (story.isEvent) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(icon: const Icon(Icons.notifications_outlined), label: const Text('전날 오전 9시 알림'), onPressed: () async {
            try {
              await Reminders.schedule(story);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림을 예약했습니다. 절전 정책에 따라 지연될 수 있습니다.')));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is StateError ? e.message.toString() : '알림을 예약하지 못했습니다.')));
            }
          }),
          TextButton(onPressed: () async {
            try {
              await Reminders.cancel(story);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림을 취소했습니다.')));
            } catch (_) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림 취소에 실패했습니다.')));
            }
          }, child: const Text('이 일정 알림 취소')),
          if (story.id.startsWith('personal:')) TextButton(onPressed: () async {
            final app = context.read<AppState>();
            await Reminders.cancel(story);
            await app.removeEvent(story.id);
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('개인 일정 삭제')),
        ],
        const SizedBox(height: 12),
        if (story.url.isNotEmpty) FilledButton.icon(icon: const Icon(Icons.open_in_new), label: const Text('원문 열기'), onPressed: () async {
          final uri = Uri.tryParse(story.url);
          try {
            if (uri == null || uri.scheme != 'https' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              throw StateError('Cannot open URL');
            }
          } catch (_) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('원문 링크를 열지 못했습니다.')));
          }
        }),
      ])));
  }
}
