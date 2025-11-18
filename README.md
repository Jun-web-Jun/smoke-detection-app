# 흡연 감지 시스템 - Flutter 앱

AI 기반 실시간 흡연 감지 모니터링 시스템의 Flutter 모바일 앱입니다.

## 프로젝트 개요

라즈베리파이가 흡연 행위를 감지하면 앱에서 라이브 화면을 확인하고, 이벤트(이미지+메타데이터)를 저장/열람하며, 조건별 푸시알림을 받는 기능을 제공합니다.

## 주요 기능

### 1. 스플래시 & 로그인
- 간단한 Firebase 익명 로그인 UI
- 스플래시 화면으로 브랜딩

### 2. 홈 탭
- 오늘의 감지 건수 표시
- 최근 3건의 이벤트 카드 표시
- 라이브, 이벤트, 설정으로 빠른 이동

### 3. 라이브 탭
- MJPEG 스트림 표시 영역 (준비됨)
- 연결 상태 표시기 (연결됨/연결 중/오류/연결 안 됨)
- 스트림 시작/중지 버튼
- 스냅샷 캡처 기능

### 4. 이벤트 탭
- **리스트**: 시간, 라벨, 신뢰도, 썸네일 정보 카드
- **필터**: 날짜 범위 및 라벨(사람, 담배, 연기, 불) 필터
- **상세**: 원본 이미지, 메타데이터, 공유/다운로드 버튼

### 5. 설정 탭
- 알림 ON/OFF 토글
- 감지 유형별 활성화 설정
- 신뢰도 임계값 조정 (슬라이더)
- 스트림 URL 관리
- 다크 모드/라이트 모드 전환
- 설정 초기화

## 기술 스택

- **프레임워크**: Flutter 3.0+
- **상태 관리**: flutter_riverpod
- **라우팅**: go_router
- **MJPEG 스트림**: mjpeg 패키지
- **이미지 캐싱**: cached_network_image
- **환경 변수**: flutter_dotenv
- **Firebase**: firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging (준비됨)

## 프로젝트 구조

```
lib/
├── main.dart                      # 앱 진입점
├── models/                        # 데이터 모델
│   ├── detection_event.dart       # 감지 이벤트 모델
│   └── app_settings.dart          # 앱 설정 모델
├── screens/                       # 화면 위젯
│   ├── auth/                      # 인증 관련 화면
│   │   ├── splash_screen.dart
│   │   └── login_screen.dart
│   ├── home/                      # 홈 탭
│   │   └── home_screen.dart
│   ├── live/                      # 라이브 탭
│   │   └── live_screen.dart
│   ├── events/                    # 이벤트 탭
│   │   ├── events_screen.dart
│   │   ├── event_detail_screen.dart
│   │   └── filter_bottom_sheet.dart
│   └── settings/                  # 설정 탭
│       └── settings_screen.dart
├── widgets/                       # 재사용 가능한 위젯
│   ├── event_card.dart            # 이벤트 카드 위젯
│   └── main_navigation.dart       # 하단 네비게이션 바
├── providers/                     # Riverpod 프로바이더
│   ├── events_provider.dart       # 이벤트 상태 관리
│   ├── settings_provider.dart     # 설정 상태 관리
│   ├── stream_provider.dart       # 스트림 상태 관리
│   └── theme_mode_provider.dart   # 테마 상태 관리
├── services/                      # 비즈니스 로직
│   └── dummy_data.dart            # 더미 데이터 서비스
├── theme/                         # 테마 설정
│   └── app_theme.dart             # 앱 테마 (라이트/다크)
├── router/                        # 라우팅 설정
│   └── app_router.dart            # GoRouter 설정
└── utils/                         # 유틸리티
    └── date_formatter.dart        # 날짜 포맷팅
```

## 시작하기

### 요구사항
- Flutter SDK 3.0 이상
- Dart SDK 3.0 이상

### 설치

1. 저장소 클론 또는 프로젝트 디렉토리로 이동

2. 의존성 설치:
```bash
flutter pub get
```

3. `.env` 파일 확인 (이미 생성됨):
```
MJPEG_STREAM_URL=http://localhost:8080/stream
```

### 실행

```bash
flutter run
```

### 테스트

```bash
flutter test
```

## 현재 구현 상태

✅ **완료된 기능**:
- 4개 탭 UI 구현 (홈, 라이브, 이벤트, 설정)
- 더미 데이터를 활용한 UI 표시
- 화면 간 내비게이션
- Material Design 3 적용
- 다크 모드/라이트 모드 지원
- 반응형 디자인
- 위젯 테스트

⏳ **향후 작업 필요**:
- 실제 Firebase 연동
- MJPEG 스트림 실제 구현
- 푸시 알림 구현
- 이미지 공유/다운로드 실제 구현
- 데이터 필터링 Provider 연동
- 로컬 저장소 연동 (SharedPreferences)

## 디자인 특징

- **Material Design 3**: 최신 디자인 가이드라인 준수
- **다크 모드**: 시스템 테마에 따른 자동 전환 지원
- **반응형**: 다양한 화면 크기 지원
- **일관성**: 통일된 컬러 스키마와 아이콘 사용
- **접근성**: 충분한 대비와 터치 영역 확보

## 라벨별 색상 및 아이콘

| 라벨 | 한글명 | 색상 | 아이콘 |
|------|--------|------|--------|
| person | 사람 | Blue | person |
| cigarette | 담배 | Red | smoking_rooms |
| smoke | 연기 | Orange | cloud |
| fire | 불 | Deep Orange | local_fire_department |

## 더미 데이터

현재 구현은 더미 데이터를 사용하여 UI를 시연합니다:
- 8개의 샘플 감지 이벤트
- 4가지 감지 유형 (사람, 담배, 연기, 불)
- Placeholder 이미지 사용

실제 Firebase 연동 시 `lib/services/dummy_data.dart`를 Firebase 서비스로 교체해야 합니다.

## 환경 변수

`.env` 파일에서 다음 변수를 설정할 수 있습니다:
- `MJPEG_STREAM_URL`: MJPEG 스트림 URL

## 라이선스

이 프로젝트는 교육 및 데모 목적으로 제작되었습니다.

## 문의

프로젝트 관련 문의사항은 이슈로 남겨주세요.
