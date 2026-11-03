# ARM64 APK 배포

1. Flutter 3.35.7 / JDK 17 / Android SDK를 준비합니다. `flutter pub get`, 분석, 테스트, debug ARM64 APK 빌드와 실제 단말 검증을 수행합니다. 최초 생성한 `pubspec.lock`을 커밋하세요.
2. 앱 업데이트에 계속 사용할 **개인 서명 키**를 준비해 안전하게 백업합니다. 기존 키가 없다면 신뢰하는 로컬 PC에서 아래 명령을 실행합니다. 비밀번호는 도구의 대화형 입력에만 입력합니다.

   ```sh
   keytool -genkeypair -v -keystore game-brief-release.jks -alias gamebrief -keyalg RSA -keysize 3072 -validity 10000
   ```

3. GitHub 저장소 Settings → Secrets and variables → Actions에 다음 값을 등록합니다. 키나 비밀번호를 채팅·소스·Release에 올리지 마세요.

   - `ANDROID_KEYSTORE_BASE64`: 위 keystore의 base64 인코딩 내용
   - `ANDROID_STORE_PASSWORD`: keystore 비밀번호
   - `ANDROID_KEY_ALIAS`: 위 alias (`gamebrief`)
   - `ANDROID_KEY_PASSWORD`: 개인 키 비밀번호

4. PR 검증이 성공한 변경을 main에 머지합니다. Actions의 **Publish signed ARM64 APK**를 main에서 실행하고 새 버전 태그(예: `v1.0.0`)를 입력합니다. Actions 쓰기 권한과 Releases 생성 권한이 필요합니다.
5. 워크플로는 분석·테스트, release 빌드, APK 서명 검증 후 `game-brief-arm64.apk`와 `SHA256SUMS`를 새 Release에 게시합니다. 기존 태그는 덮어쓰지 않습니다. 게시 단계 실패로 태그만 생성된 경우에는 실패 원인을 확인하고 해당 커밋·APK를 검토한 후 복구하세요.
6. GitHub Release에서 APK를 내려받아 Android ARM64 기기에 설치합니다. 출처 허용, RAWG 키, 번역 모델 다운로드, Android 13+ 알림 권한을 확인합니다. 앱 버전 업그레이드에는 같은 서명 키가 필요합니다.

로컬 release 빌드는 `android/key.properties`에 `storeFile` 절대 경로와 `storePassword`, `keyAlias`, `keyPassword`를 설정한 뒤 실행합니다. 해당 파일과 keystore는 Git에서 제외됩니다. 키 없이 만든 unsigned release APK는 게시·설치용으로 사용할 수 없습니다.

## 기기 검증

- 키 없는 RSS 새로고침, 각 플랫폼 필터, 오프라인 재시작 캐시
- RAWG 키 입력 후 날짜 선택 및 일정 표시
- 처음에는 원문 표시, 상세 A/가 번역, 이후 캐시 재사용
- 쇼케이스 개인 일정 추가·재시작·삭제
- 알림 권한 거부·허용, 예약·취소·재부팅 후 유지
- Android 절전 모드 및 시간대 변경 상황
