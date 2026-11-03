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

Flutter **3.35.7** (Dart 3.9), JDK 17, Android SDK 필요. Android 최소 API 23, ARM64 대상.

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

소스의 `pubspec.lock`은 최초 성공적인 `flutter pub get` 후 커밋해 의존성 해석을 고정해야 합니다. 현재 클라우드에서 SDK 다운로드가 차단되어 lockfile과 실행 결과는 아직 생성하지 못했습니다. 구현·테스트 파일 작성은 실행 검증 완료를 의미하지 않습니다.

## 검증 상태

이 작업에서는 네트워크 정책에 의해 Dart SDK 다운로드와 GitHub API가 차단되었습니다. 따라서 `flutter analyze`, `flutter test`, Android 빌드, 기기 설치, PR 머지, APK 게시를 아직 수행하지 못했습니다. 작성된 테스트는 캐시 TTL, 필터의 무통신 동작, 요청 병합, 오류 복구, RSS 파싱, 일정 저장 및 상세 화면의 지연 번역을 검증하도록 구성했습니다. 실제 통과 여부는 SDK 준비 후 확인해야 합니다.
