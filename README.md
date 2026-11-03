# Game Brief

개인용 Android ARM64 게임 뉴스·발매 일정 앱. Flutter 3.35.7 / JDK 17 / Android 7.0(API 24) 이상.

## Gemini 번역 설정

1. 앱 설정 → **Google AI Studio에서 API 키 발급**을 누릅니다.
2. https://aistudio.google.com/apikey 에서 로그인하고 키를 생성·복사합니다.
3. Gemini API 키 입력란에 붙여넣고 저장합니다. 키는 기기 보안 저장소에 보관합니다.
4. **키 확인 및 모델 업데이트 확인**으로 키와 사용 가능한 안정판 Flash 모델을 확인할 수 있습니다.

기본 모델은 2026-11-03 확인한 [Google 공식 시작 예제](https://github.com/google-gemini/cookbook/blob/main/quickstarts/Get_started.ipynb)의 기본 권장 모델 `gemini-3.8-flash`입니다. 구글 모델 문서 https://ai.google.dev/gemini-api/docs/models 는 이번 클라우드에서 차단되어, 접근 가능한 공식 예제를 확인했습니다.

새 번역이 필요하면 하루 한 번 공식 Models API로 사용 가능 여부를 확인합니다. 지원 종료 모델은 생성 요청 전에 중단하고 설정에서 다른 안정판 Flash 모델을 선택하도록 안내합니다. 새 모델은 설정에서 직접 선택합니다. Pro·프리뷰로 자동 변경하지 않습니다. 모델별 요금·무료 한도는 다르며 다른 앱과 같은 프로젝트 키를 쓰면 한도를 공유합니다.

## 조회 및 토큰 절약

- 시작 시 전체 피드를 불러오지 않습니다. PC / PS5 / Nintendo / Mobile 중 하나를 누를 때 조회합니다.
- RSS 제공자는 통합 피드를 반환하므로 원본 RSS를 받아 선택 기기의 기사만 로컬에서 선별합니다. 다른 기기의 기사는 Gemini에 보내지 않습니다. 웹 크롤링은 하지 않습니다.
- 선택한 기기의 최신 제목 최대 20개를 한 번에 번역합니다. 각 기기의 피드는 별도로 12시간 캐시합니다.
- 같은 원문·모델의 번역은 재사용합니다. 본문(RSS 요약)은 상세 화면 A/가를 눌러야 전송합니다.
- 빈 키는 번역 호출 없이 원문을 표시합니다. 429 이후 1분 중단하며 자동 재시도는 하지 않습니다. 입력 20,000자·출력 8,192토큰 상한을 적용합니다.
- 달력은 선택했을 때 RAWG 일정만 조회합니다. 일정 제목은 일괄 번역하지 않고 상세 화면에서 요청할 수 있습니다. RAWG 키는 선택 사항입니다.
- 뉴스 원문·요약이 Google에 전송됩니다. 개인정보·무료 티어 데이터 사용 조건은 https://ai.google.dev/gemini-api/terms 와 요금 안내를 확인하세요.

## 개발 및 배포

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter test --dart-define=LIVE_FEEDS=true test/live_feed_test.dart
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

[배포 절차](docs/deployment.md). 서명 키·비밀번호는 저장소에 포함하지 않습니다. 기존 정식 v1.0.0과 동일 서명 키를 사용하므로 업데이트 설치할 수 있습니다. debug 테스트 앱과는 서명이 다릅니다.

Gemini 응답·배치·캐시·429·모델 지원 종료는 HTTP mock 테스트로 검증합니다. 실제 사용자 API 키로 번역 품질·요금·모델 사용 권한을 검증한 것은 아니며 사용자 입력 후 확인해야 합니다.
