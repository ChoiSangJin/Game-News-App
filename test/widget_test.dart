import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_news_app/data/cache.dart';
import 'package:game_news_app/main.dart';
import 'package:game_news_app/state/app_state.dart';
import 'core_test.dart' show FakeSource, FakeTranslator, sample;

void main() {
  testWidgets('feed platform filters, calendar and lazy detail translation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = FeedCache(await SharedPreferences.getInstance());
    await cache.save([sample()], DateTime.now());
    final source = FakeSource(); final translator = FakeTranslator();
    final state = AppState(cache, source, translator);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const GameNewsApp()));
    expect(find.text('PC launch'), findsOneWidget);
    await tester.tap(find.text('PS5')); await tester.pumpAndSettle();
    expect(find.text('PC launch'), findsNothing);
    await tester.tap(find.text('PC')); await tester.pumpAndSettle();
    await tester.tap(find.text('PC launch')); await tester.pumpAndSettle();
    expect(translator.texts, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'A / 가')); await tester.pumpAndSettle();
    expect(translator.texts, ['PC launch', 'Summary body']);
    expect(find.text('번역: Summary body'), findsOneWidget);
    await tester.pageBack(); await tester.pumpAndSettle();
    await tester.tap(find.text('이벤트 달력')); await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('발매 일정 연결'), findsOneWidget);
    expect(source.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
