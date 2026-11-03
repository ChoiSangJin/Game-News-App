import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/story.dart';
import '../state/app_state.dart';

Future<void> addPersonalEvent(BuildContext context, DateTime day) async {
  final title = TextEditingController();
  final source = TextEditingController();
  String kind = '쇼케이스';
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
    builder: (context, setDialogState) => AlertDialog(title: const Text('개인 일정 추가'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${day.year}.${day.month}.${day.day} · 선택한 날짜'),
        DropdownButton<String>(value: kind, isExpanded: true, items: ['쇼케이스','게임쇼','발매일','이벤트']
          .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setDialogState(() => kind = v!)),
        TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: '일정 이름')),
        TextField(controller: source, decoration: const InputDecoration(labelText: '공식 출처 HTTPS 링크 (선택)')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
        FilledButton(onPressed: () async {
          if (title.text.trim().isEmpty) return;
          final url = source.text.trim();
          if (url.isNotEmpty && (Uri.tryParse(url)?.scheme != 'https' || Uri.tryParse(url)!.host.isEmpty)) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('올바른 HTTPS 출처 링크를 입력하세요.')));
            return;
          }
          await dialogContext.read<AppState>().addEvent(Story(
            id: 'personal:${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(),
            body: '$kind · 직접 등록한 일정', source: '내 일정', url: url, date: day, isEvent: true));
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('추가')),
      ])));
  await Future<void>.delayed(const Duration(milliseconds: 400));
  title.dispose();
  source.dispose();
}
