# Game Brief

Flutter로 만든 개인용 Android 게임 뉴스·발매 일정 앱. 서버나 웹 크롤링 없이 RSS와 공개 API를 사용합니다.

## 기능

- 하단 뉴스 / 이벤트 달력, 전체·PC·PS5·Nintendo·Mobile 필터
- PC Gamer, GameSpot RSS의 제목·요약·출처·원문 링크
- 12시간 로컬 캐시. 앱 실행·복귀·하단 탭 전환 시 만료된 경우만 갱신. 플랫폼 필터는 네트워크 요청 없이 동작
- 아래로 당겨 캐시 무효화 및 갱신. 동시 요청 병합, 1분 요청 보호, 20초 HTTP 타임아웃, 실패 시 오래된 캐시 유지
- ML Kit 기기 내 영어→한국어 번역. 제목은 갱신 때 번역하고 저장, 본문 요약은 상세 화면 A/가 버튼에서만 번역. 원문 기본 표시
- RAWG 발매일: 설정에서 개인 키 입력. 앞으로 180일 중 날짜가 확정된 최대 40개 조회. 전체 게임 일정을 보장하지 않음
- 쇼케이스·게임쇼는 공식 출처를 확인해 날짜별 개인 일정으로 등록·삭제
- 일정별 전날 오전 9시 알림 예약·취소. Android 13 이상 알림 권한 요청. 절전 정책에 따른 지연 가능. 시간대 변경 후 다시 예약
- 게임패드+뉴스/달력 모양 자체 아이콘. `flutter_launcher_icons` 설정 포함

## 개발

Flutter **3.35.7** (Dart 3.9), JDK 17, Android SDK 필요. Android 최소 API 24, ARM64 대상.

```sh
flutter pub get
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
flutter run
```

기본 키 없이 뉴스가 동작합니다. RAWG 키는 앱 설정에 입력하며 `flutter_secure_storage`에 저장합니다. API 키나 서명 키를 소스에 포함하지 마세요. 첫 번역 시 모델을 다운로드하므로 네트워크와 저장 공간이 필요합니다. 번역 모델 실패는 원문으로 대체하며 상세 화면에서 재시도할 수 있습니다.

피드 수집 경로: `https://www.pcgamer.com/rss/`, `https://www.gamespot.com/feeds/mashup/`. 일정: `https://api.rawg.io/api/games`. 공식 API 문서: https://rawg.io/apidocs . 외부 피드 제공 중단·요청 제한 시 UI에 실패 상태를 표시하며 기존 데이터를 유지합니다. ML Kit 모델은 Google의 공식 모델 배포 경로로 다운로드합니다.

## APK 게시

[배포 절차](docs/deployment.md)를 참고하세요. CI는 분석·테스트·ARM64 debug APK 빌드를 수행합니다. Release 워크플로는 main에서 수동 실행하며 동일 검증 후 개인 서명 키로 ARM64 release APK를 서명하고 GitHub Releases에 APK와 SHA256 체크섬을 게시합니다. 검증 실패 시 게시하지 않습니다.

소스의 `pubspec.lock`은 최초 성공적인 `flutter pub get` 후 커밋해 의존성 해석을 고정해야 합니다. 생성된 lockfile을 저장소에 포함했습니다.

## 검증 상태

[GitHub Actions](https://github.com/ChoiSangJin/Game-News-App/actions/runs/41558211660)에서 Flutter 분석, 단위·위젯 테스트, 실제 공개 RSS 수집·파싱 및 ARM64 APK 빌드를 통과했습니다. 클라우드에서도 ARM64 APK를 빌드하고 서명을 검증했습니다. 기기 설치·번역 모델 다운로드·실제 알림 수신은 아직 검증하지 않았습니다.

정식 APK는 [GitHub Releases](https://github.com/ChoiSangJin/Game-News-App/releases)에서 다운로드합니다. Android 7.0(API 24) 이상 ARM64 대상입니다. 이전 debug 테스트 앱을 설치했다면 서명이 다르므로 삭제 후 정식 APK를 설치해야 합니다. 삭제 시 로컬 데이터가 사라질 수 있습니다.

개인 배포 서명 키는 저장소 밖에 보관하며 소스와 Release에는 포함하지 않습니다. GitHub Actions에서 후속 버전을 배포하려면 docs/deployment.md에 명시한 서명 비밀값을 등록해야 합니다. 최초 배포 키를 계속 사용해야 기존 앱 위에 업데이트할 수 있습니다.
