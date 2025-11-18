# 빠른 시작 가이드

## 프로젝트 개요
흡연 감지 시스템의 Flutter 모바일 앱 UI 구현입니다.

## 필수 요구사항
- Flutter SDK 3.0 이상
- Dart SDK 3.0 이상
- Android Studio 또는 VS Code (Flutter 플러그인 설치)
- Android/iOS 에뮬레이터 또는 실제 디바이스

## 1분 만에 시작하기

### 1단계: 의존성 설치
```bash
cd c:\app\apptest
flutter pub get
```

### 2단계: 앱 실행
```bash
flutter run
```

### 3단계: 테스트 실행 (선택사항)
```bash
flutter test
```

## 앱 구조 탐색

### 주요 화면
1. **스플래시 화면** → 2초 후 자동 전환
2. **로그인 화면** → "익명으로 시작하기" 버튼 클릭
3. **메인 화면** (4개 탭):
   - 🏠 홈: 오늘의 감지 건수 + 최근 이벤트
   - 📹 라이브: MJPEG 스트림 뷰어 (더미)
   - 📋 이벤트: 감지 이벤트 목록 + 필터
   - ⚙️ 설정: 알림, 감지 설정, 테마 전환

### 인터랙션 테스트
- 홈 탭에서 이벤트 카드 클릭 → 상세 화면
- 이벤트 탭에서 필터 아이콘 클릭 → 필터 바텀시트
- 설정 탭에서 다크 모드 토글
- 라이브 탭에서 시작/중지 버튼 클릭

## 파일 개수 요약
- **총 Dart 파일**: 20개
  - 모델: 2개
  - 화면: 8개
  - 위젯: 2개
  - 프로바이더: 4개
  - 서비스: 1개
  - 테마: 1개
  - 라우터: 1개
  - 유틸리티: 1개

## 더미 데이터
- 8개의 샘플 이벤트 (사람, 담배, 연기, 불)
- Placeholder 이미지 사용 (via.placeholder.com)
- 실제 Firebase 연동 시 교체 필요

## 트러블슈팅

### 문제: "pub get" 실패
**해결**: Flutter SDK 버전 확인
```bash
flutter --version
flutter upgrade
```

### 문제: 앱이 시작되지 않음
**해결**: 에뮬레이터 확인
```bash
flutter devices
flutter run -d <device-id>
```

### 문제: 이미지가 로딩되지 않음
**해결**: 인터넷 연결 확인 (placeholder 이미지는 외부 URL 사용)

## 다음 단계
1. README.md 읽기: 전체 프로젝트 문서
2. PROJECT_SUMMARY.md 읽기: 구현 상세 내역
3. lib/ 폴더의 코드 탐색: 모든 코드에 한글 주석 포함

## 주요 개발 명령어

```bash
# 의존성 설치
flutter pub get

# 앱 실행 (디버그 모드)
flutter run

# 앱 실행 (릴리스 모드)
flutter run --release

# 테스트 실행
flutter test

# 코드 분석
flutter analyze

# 빌드 (Android APK)
flutter build apk

# 빌드 (iOS)
flutter build ios

# 패키지 업그레이드
flutter pub upgrade
```

## 개발 팁
- Hot Reload: `r` 키 (앱 실행 중)
- Hot Restart: `R` 키 (앱 실행 중)
- 위젯 검사: Flutter DevTools 사용
- 상태 확인: Riverpod 디버깅 도구 활용

## 연락처
프로젝트 관련 질문이나 이슈는 GitHub Issues에 등록해주세요.

---
**버전**: 1.0.0+1
**마지막 업데이트**: 2024년
