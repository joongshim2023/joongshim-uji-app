# Firebase Hosting 배포 & 도메인 연결 가이드

## 준비 완료 항목 ✅
- [firebase.json](file:///Users/jahyun/developer/joongshim-uji-app/firebase.json) — Hosting 설정 (build/web, SPA rewrite, 캐시 최적화)
- [.firebaserc](file:///Users/jahyun/developer/joongshim-uji-app/.firebaserc) — 프로젝트 ID `joongshim-uji` 연결
- `firebase-tools` — Node.js 22 기반으로 재설치 완료

---

## 🖥️ 내가 터미널에서 할 일 (순서대로)

### Step 1. PATH 설정 (zshrc에 추가)
터미널을 새로 열거나 아래 명령 실행:
```bash
echo 'export PATH="/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
확인:
```bash
node --version   # v22.x.x
firebase --version
```

---

### Step 2. Firebase 로그인
```bash
firebase login
```
→ 브라우저가 열리면 Firebase 프로젝트 오너 Google 계정으로 로그인

---

### Step 3. Flutter 웹 빌드
```bash
cd /Users/jahyun/developer/joongshim-uji-app
flutter build web --release
```
→ `build/web/` 폴더 생성됨

---

### Step 4. 배포
```bash
firebase deploy --only hosting
```
→ 완료 후 아래 URL로 접속 가능:
- `https://joongshim-uji.web.app`
- `https://joongshim-uji.firebaseapp.com`

---

### Step 5. 커스텀 도메인 추가 (Firebase 콘솔)

1. [Firebase Console](https://console.firebase.google.com) → `joongshim-uji` 프로젝트
2. 좌측 **Hosting** 탭 클릭
3. **"Add custom domain"** 버튼 클릭
4. 도메인 입력: `app.joongshim.co.kr`
5. Firebase가 **A레코드 2개** 또는 **TXT 인증 레코드**를 알려줌 → 메모해 두기

---

## 🌐 가비아(Gabia)에서 해야 할 일

### DNS 설정 위치
가비아 로그인 → **My가비아** → **도메인 관리** → `joongshim.co.kr` → **DNS 설정**

### 추가할 레코드 (Firebase가 알려주는 값으로 입력)

| 타입 | 호스트 | 값(IP/주소) | TTL |
|------|--------|------------|-----|
| `A` | `app` | Firebase IP ① | 600 |
| `A` | `app` | Firebase IP ② | 600 |

> Firebase 콘솔에서 알려주는 정확한 IP 주소를 입력해야 합니다.
> 보통 `151.101.x.x` 형태의 IP 2개입니다.

### TXT 인증 레코드 (소유권 인증용, 임시)
| 타입 | 호스트 | 값 |
|------|--------|----|
| `TXT` | `app` | Firebase가 알려주는 값 |

---

## ⏱️ 적용 시간
- DNS 전파: 보통 **10분~1시간** (최대 48시간)
- Firebase SSL 인증서 자동 발급: **수 분**

---

## 🔒 추가 확인 사항 (Firebase 콘솔)

Flutter 웹 앱에서 Google 로그인이 사용되므로:

1. Firebase Console → **Authentication** → **Settings** → **Authorized domains**
2. `app.joongshim.co.kr` 추가

> Google 로그인은 등록된 도메인에서만 동작합니다. 이 설정 없으면 로그인 실패!

---

## 📋 배포 후 체크리스트

- [ ] `https://app.joongshim.co.kr` 접속 확인
- [ ] 로그인 동작 확인 (Authorized domains 등록 필요)
- [ ] 이메일/Google/Apple 로그인 테스트
- [ ] 데이터 로드 정상 확인 (Firestore 보안 규칙)

---

## 🔄 이후 업데이트 배포 (간단)
```bash
flutter build web --release && firebase deploy --only hosting
```

