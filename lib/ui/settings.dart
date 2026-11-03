import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController keyInput;
  @override
  void initState() {
    super.initState();
    keyInput = TextEditingController(text: context.read<AppState>().rawgKey);
  }
  bool saving = false;
  String? error;
  @override
  void dispose() { keyInput.dispose(); super.dispose(); }
  Future<void> save() async {
    setState(() { saving = true; error = null; });
    final app = context.read<AppState>();
    try {
      final key = keyInput.text.trim();
      if (key.isEmpty) { await const FlutterSecureStorage().delete(key: 'rawg_key'); }
      else { await const FlutterSecureStorage().write(key: 'rawg_key', value: key); }
      await app.changeKey(key);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = '설정을 저장하지 못했습니다. 다시 시도하세요.');
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('설정')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('일정을 연결하세요', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('rawg.io/apidocs에서 개인용 무료 API 키를 발급받으세요. 키는 이 기기의 보안 저장소에 보관하며 RAWG에만 전송합니다. 뉴스 RSS는 키 없이 사용할 수 있습니다.'),
      const SizedBox(height: 20),
      TextField(controller: keyInput, obscureText: true, autocorrect: false, enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'RAWG API key', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? '저장 및 갱신 중…' : '저장하고 갱신')),
      if (error != null) Text(error!),
      const Divider(height: 40),
      const Text('번역과 데이터', style: TextStyle(fontSize: 20)),
      const SizedBox(height: 12),
      const Text('제목은 피드 갱신 시 기기 내에서 번역하고, RSS 본문 요약은 상세 화면의 A/가 버튼을 눌렀을 때만 번역합니다. 첫 사용에는 영어·한국어 모델 다운로드가 필요하며 데이터 요금이 발생할 수 있습니다. 원문이 기본 표시됩니다.\n\n데이터는 12시간 캐시합니다. 아래로 당기면 캐시를 무효화하고 갱신합니다. 과도한 요청 방지를 위해 새 요청 간 최소 1분을 둡니다. 오프라인에서는 기존 메모리 데이터를 유지합니다.\n\n출처: PC Gamer RSS, GameSpot RSS, RAWG. RAWG 발매 일정은 앞으로 180일 중 최대 40개이며, 쇼케이스·게임쇼는 공식 출처를 확인해 개인 일정으로 추가할 수 있습니다. 일정 상세에서 전날 오전 9시 알림을 예약하거나 취소할 수 있습니다. 알림은 Android 절전 정책에 따라 지연될 수 있으며 시간대 변경 후에는 다시 예약하세요.'),
    ]));
}
