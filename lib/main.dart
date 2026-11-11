import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/cache.dart';
import 'data/sources.dart';
import 'data/translation.dart';
import 'state/app_state.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final translator = GeminiTranslator(prefs, http.Client());
  final state = AppState(
    FeedCache(prefs),
    PublicFeeds(http.Client()),
    translator,
  );
  try {
    translator.apiKey =
        await const FlutterSecureStorage().read(key: 'gemini_key') ?? '';
  } catch (_) {
    /* Restore the other provider independently. */
  }
  try {
    state.rawgKey =
        await const FlutterSecureStorage().read(key: 'rawg_key') ?? '';
  } catch (_) {
    /* News still works if this provider cannot be restored. */
  }
  runApp(
    ChangeNotifierProvider.value(value: state, child: const GameNewsApp()),
  );
  // No feed or translation requests until a platform is selected.
}

class GameNewsApp extends StatelessWidget {
  const GameNewsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Game Brief',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF99EDBB),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101727),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF101727)),
    ),
    builder: (context, child) =>
        SafeArea(top: false, child: child ?? const SizedBox.shrink()),
    home: const HomePage(),
  );
}
