# Firebase 설정 가이드

## 1단계: Firebase 프로젝트 생성

### 1.1 Firebase 콘솔 접속
1. https://console.firebase.google.com/ 접속
2. Google 계정으로 로그인

### 1.2 새 프로젝트 생성
1. "프로젝트 추가" 클릭
2. 프로젝트 이름: **smoke-detection-system** 입력
3. Google 애널리틱스 사용 여부 선택 (선택사항)
4. "프로젝트 만들기" 클릭

### 1.3 Firebase 서비스 활성화

#### Authentication 설정
1. 좌측 메뉴 > "빌드" > "Authentication" 클릭
2. "시작하기" 클릭
3. "로그인 방법" 탭 선택
4. "익명" 선택 > "사용 설정" 토글 ON > "저장"

#### Firestore Database 설정
1. 좌측 메뉴 > "빌드" > "Firestore Database" 클릭
2. "데이터베이스 만들기" 클릭
3. 위치 선택: **asia-northeast3 (서울)** 권장
4. 보안 규칙: "테스트 모드로 시작" 선택 (나중에 변경)
5. "사용 설정" 클릭

#### Storage 설정
1. 좌측 메뉴 > "빌드" > "Storage" 클릭
2. "시작하기" 클릭
3. 보안 규칙: "테스트 모드로 시작" 선택
4. 위치: **asia-northeast3 (서울)** 선택
5. "완료" 클릭

#### Cloud Messaging (FCM) 설정
1. 좌측 메뉴 > "빌드" > "Cloud Messaging" 클릭
2. 자동으로 활성화됨 (별도 설정 불필요)

---

## 2단계: Flutter 웹 앱 등록

### 2.1 웹 앱 추가
1. Firebase 프로젝트 개요 > "앱 추가" (</> 웹 아이콘) 클릭
2. 앱 닉네임: **Smoke Detection Web App** 입력
3. Firebase 호스팅 설정: 체크 안함
4. "앱 등록" 클릭

### 2.2 Firebase 구성 정보 복사
다음과 같은 구성 정보가 표시됩니다:

```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "smoke-detection-system.firebaseapp.com",
  projectId: "smoke-detection-system",
  storageBucket: "smoke-detection-system.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef",
  measurementId: "G-XXXXXXX"
};
```

**이 정보를 복사해서 저장해주세요!**

### 2.3 구성 파일 생성
복사한 정보를 바탕으로 다음 파일을 생성합니다:

**파일: `lib/firebase_options.dart`** (제가 템플릿 제공 예정)

---

## 3단계: Firestore 보안 규칙 설정

Firestore Database > "규칙" 탭에서 다음 규칙을 적용:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 읽기: 인증된 사용자만 허용
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /devices/{deviceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /app_config/{config} {
      allow read: if request.auth != null;
      allow write: if false; // 관리자만 쓰기 가능
    }
  }
}
```

"게시" 클릭

---

## 4단계: Storage 보안 규칙 설정

Storage > "규칙" 탭에서 다음 규칙을 적용:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /detection_images/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /screenshots/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

"게시" 클릭

---

## 5단계: 서비스 계정 키 생성 (라즈베리파이용)

라즈베리파이에서 Firebase Admin SDK를 사용하려면 서비스 계정 키가 필요합니다.

1. 프로젝트 설정 > "서비스 계정" 탭
2. "새 비공개 키 생성" 클릭
3. "키 생성" 클릭
4. JSON 파일이 다운로드됨
5. 파일 이름을 **`firebase-service-account.json`** 으로 변경
6. 라즈베리파이 프로젝트 폴더에 저장 (나중에 사용)

**⚠️ 주의: 이 파일은 절대 공개하지 마세요! Git에 커밋하지 마세요!**

---

## 완료!

위 단계를 모두 완료하면:
- ✅ Firebase 프로젝트 생성 완료
- ✅ Authentication, Firestore, Storage, FCM 활성화
- ✅ 웹 앱 등록 및 구성 정보 확보
- ✅ 보안 규칙 설정
- ✅ 서비스 계정 키 다운로드

다음은 Flutter 앱에 Firebase SDK를 통합하는 작업입니다.
