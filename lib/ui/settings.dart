import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/translation.dart';
import '../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController rawg;
  late final TextEditingController keyInput;
  GeminiTranslator? get translator {
    final value = context.read<AppState>().translator;
    return value is GeminiTranslator ? value : null;
  }

  bool saving = false;
  String? message;
  @override
  void initState() {
    super.initState();
    rawg = TextEditingController(text: context.read<AppState>().rawgKey);
    keyInput = TextEditingController(text: translator?.apiKey ?? '');
  }

  @override
  void dispose() {
    rawg.dispose();
    keyInput.dispose();
    super.dispose();
  }

  Future<void> open(String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('링크를 열지 못했습니다.');
      }
    } catch (_) {
      if (mounted) setState(() => message = '브라우저에서 $url 주소를 열어 주세요.');
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      message = null;
    });
    final app = context.read<AppState>();
    try {
      const storage = FlutterSecureStorage();
      final key = keyInput.text.trim();
      if (key.isEmpty) {
        await storage.delete(key: 'gemini_key');
      } else {
        await storage.write(key: 'gemini_key', value: key);
      }
      translator?.apiKey = key;
      final rawgKey = rawg.text.trim();
      if (rawgKey.isEmpty) {
        await storage.delete(key: 'rawg_key');
      } else {
        await storage.write(key: 'rawg_key', value: rawgKey);
      }
      if (rawgKey != app.rawgKey) {
        await app.changeKey(rawgKey);
      } else {
        await app.cache.invalidate();
        await app.refresh(force: true);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => message = '저장하지 못했습니다. 다시 시도하세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> models() async {
    final t = translator;
    if (t == null) return;
    setState(() {
      saving = true;
      message = null;
    });
    final original = t.apiKey;
    try {
      t.apiKey = keyInput.text.trim();
      final names = await t.checkModels();
      if (mounted) {
        setState(
          () => message = names.contains(t.model)
              ? '현재 모델 사용 가능 · 목록에서 새 모델을 선택할 수 있습니다.'
              : '현재 모델을 사용할 수 없습니다. 아래 목록에서 사용 가능한 모델을 선택하세요.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is StateError
              ? e.message.toString()
              : '모델 확인에 실패했습니다. 인터넷 연결을 확인하세요.',
        );
      }
    } finally {
      t.apiKey = original;
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = translator;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Gemini 번역 연결',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            '1. 아래 버튼을 눌러 Google 계정으로 로그인하세요.\n2. API 키 만들기를 누른 뒤 키를 복사하세요.\n3. 아래에 붙여넣고 저장하세요. 이미 다른 앱에서 쓰는 키도 사용할 수 있으며 프로젝트 한도는 공유됩니다.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => open('https://aistudio.google.com/apikey'),
            icon: const Icon(Icons.key),
            label: const Text('Google AI Studio에서 API 키 발급'),
          ),
          const SelectableText('https://aistudio.google.com/apikey'),
          const SizedBox(height: 16),
          TextField(
            controller: keyInput,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Gemini API 키 붙여넣기',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('선택 모델: ${t?.model ?? GeminiTranslator.recommendedModel}'),
          const Text(
            '기본값은 구글 공식 시작 예제의 권장 Flash 모델입니다. 모델 목록 확인은 번역을 생성하지 않습니다. 새 번역이 필요할 때 하루 한 번 지원 모델을 자동 확인합니다. 새 모델이나 지원 종료는 아래에서 확인하세요. 모델별 요금·한도는 다를 수 있습니다.',
          ),
          TextButton(
            onPressed: saving ? null : models,
            child: const Text('키 확인 및 모델 업데이트 확인'),
          ),
          if (t != null && t.availableModels.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: t.availableModels.contains(t.model)
                  ? t.model
                  : null,
              hint: const Text('사용 가능한 Flash 모델 선택'),
              items: t.availableModels
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) async {
                      if (value == null) return;
                      await t.setModel(value);
                      if (mounted) {
                        setState(
                          () => message = '모델을 선택했습니다. 저장하면 현재 기기의 번역을 갱신합니다.',
                        );
                      }
                    },
            ),
            if (t.prefs.getString('gemini_models_checked') != null)
              Text('마지막 확인: ${t.prefs.getString('gemini_models_checked')}'),
          ],
          TextButton(
            onPressed: () =>
                open('https://ai.google.dev/gemini-api/docs/models'),
            child: const Text('구글 공식 모델 안내'),
          ),
          const Text(
            '선택한 기기의 새 제목만 최대 20개씩 묶어 번역합니다. 상세 요약은 A/가를 눌렀을 때만 Google로 전송됩니다. 번역 결과는 기기에 저장하며 모델별로 재사용합니다. 키가 없거나 한도가 초과되면 원문을 표시합니다. 무료 한도와 데이터 처리 조건은 Google 정책을 확인하세요.',
          ),
          TextButton(
            onPressed: () =>
                open('https://ai.google.dev/gemini-api/docs/pricing'),
            child: const Text('요금·무료 한도 확인'),
          ),
          const Divider(height: 32),
          const Text('발매 일정 연결 (선택)'),
          TextButton(
            onPressed: () => open('https://rawg.io/apidocs'),
            child: const Text('RAWG API 키 발급 안내'),
          ),
          TextField(
            controller: rawg,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'RAWG API 키',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '두 키는 기기의 보안 저장소에 보관합니다. 앱 시작 시에는 조회하지 않습니다. 기기 선택 시 뉴스, 달력 선택 시 RAWG 일정만 조회합니다. 각 화면의 데이터는 12시간 캐시되며 수동 갱신은 최소 1분 간격입니다.',
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '처리 중…' : '키 저장하고 적용'),
          ),
        ],
      ),
    );
  }
}
