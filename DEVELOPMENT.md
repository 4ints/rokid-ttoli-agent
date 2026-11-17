# 로컬(Windows) 개발 가이드

똘똘이 AIUI 에이전트를 Windows PC에서 개발하고, ADB 케이블로 Rokid Glasses에 바로 설치하는 방법.

## 구조

```
Rokid Glasses (이 에이전트)
   └─ HTTPS ─▶ https://rokid-hermes.4ints.com   (Cloudflare 터널, 서버에서 상시 운영)
                 └─▶ 인증 프록시 (토큰 확인, /chat · /reset 만 허용)
                       └─▶ hermes agent (똘똘이)
```

- 서버 쪽(hermes, 프록시, 터널, 텔레그램 알림)은 그대로 서버에서 돌아간다. 로컬에서는 **에이전트 코드만** 개발한다.
- 안경 → 서버 통신은 인터넷(HTTPS)으로 하므로 PC가 어디에 있든 상관없다.

## 1. 준비 (한 번만)

```powershell
# Git, Node.js 20+ 설치 후
git clone https://github.com/4ints/rokid-ttoli-agent.git
cd rokid-ttoli-agent
npm install -g @yodaos-pkg/aix-cli
```

- **ADB**: [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools)를 풀고 그 폴더를 PATH에 추가.
- **토큰 파일**: `%USERPROFILE%\.rokid-hermes\env` 를 만들고 아래 한 줄을 넣는다.
  값은 서버의 `~/.config/rokid-hermes-proxy/env` 에 있는 것과 같다.
  ```
  ROKID_PROXY_TOKEN=<서버와 같은 값>
  ```
  Cloudflare Access를 켠 뒤에는 `CF_ACCESS_CLIENT_ID=`, `CF_ACCESS_CLIENT_SECRET=` 두 줄을 추가한다.
- **PowerShell 실행 정책**: 스크립트가 막히면 `powershell -ExecutionPolicy Bypass -File scripts\pack-local.ps1 ...` 로 실행한다.

### Claude Code를 쓸 때 (선택)

```powershell
npx skills add https://github.com/jsar-project/AIUI/tree/main/skills/aiui-dev -a claude-code -y
```

AIUI 공식 개발 스킬(API·컴포넌트·체크리스트)이 프로젝트에 설치된다. `CLAUDE.md`에 작업 규칙이 있다.

## 2. 개발 반복

| 단계 | 명령 |
|---|---|
| 브라우저 미리보기 (음성 인식은 동작하지 않음) | `aix preview . --launch` |
| 안경 연결 확인 | `adb devices` → `device` 상태여야 함, `aix device` |
| 안경에 설치 + 실행 | `.\scripts\pack-local.ps1 -Install -Launch` |
| 패키지만 만들기 | `.\scripts\pack-local.ps1` → `ttoli-agent.aix` (git 제외) |
| 로그 보기 | `adb logcat -v time \| findstr /i "aiui ttoli"` |
| 화면 캡처 | `adb exec-out screencap -p > screen.png` |

- `pack-local.ps1`은 저장소를 임시 폴더로 복사해 `config.js`에 토큰을 넣은 뒤 패키징한다. **저장소의 `config.js`에는 토큰을 넣지 않는다** (공개 저장소).
- 처음 실행할 때 로컬 에이전트 ID(`.aix\agent-id`, git 제외)가 만들어지고, 이후 같은 ID로 덮어써 설치된다.
- 안경 개발자 모드가 꺼져 있으면: `adb shell settings put global development_settings_enabled 1`

## 3. AIUI Studio로 올리기 (스토어/클라우드 배포 경로)

- **GitHub 가져오기**: 커밋·푸시 후 Studio → New Agent ▾ → Import from GitHub → 저장소 URL → Code 탭에서 `config.js`의 `PROXY_TOKEN` 입력
- **로컬 폴더 가져오기**: `.\scripts\pack-local.ps1 -Out C:\rokid-studio\ttoli-agent` 로 토큰이 들어간 사본을 저장소 밖에 만들고, Studio에서 그 폴더를 Import from local folder
- Studio **Device Debug** 탭에서 Package and Save → Hi Rokid 앱 설정 → 개발자 → 글라스 리소스 패키지 업데이트
- 스토어 심사 제출(Submit for Review)은 하지 않는다. 토큰이 패키지에 들어 있어 공개되면 안 된다.

## 4. 코드 구조

| 파일 | 역할 |
|---|---|
| `app.json` | 에이전트 이름, 페이지, 권한(`RECORD_AUDIO`) |
| `AGENTS.md` | 에이전트 설명 (플랫폼이 의도를 이해하는 데 사용) |
| `config.js` | 프록시 주소·토큰, 음성 언어(`SPEECH_LANG`), 음성 낭독(`SPEAK_REPLY`) |
| `pages/index/index.ink` | 유일한 페이지: 듣기 → 질문 → 답 표시/낭독, 카드·전체 화면 처리 |
| `lib/speech.js` | 음성 인식: `SpeechRecognition` 우선, 안 되면 `SpeechRecognitionSession` |
| `lib/asr.js` | 마이크 PCM → `SpeechRecognitionSession` (공식 샘플 기반) |
| `lib/hermes.js` | 프록시 호출 (`/chat`, `/reset`), 대화 세션 이름 저장 |
| `scripts/pack-local.ps1` | 토큰 주입 패키징/설치 (패키지에는 포함되지 않음) |

## 5. 현재 상태와 남은 확인

- [x] Studio 웹 시뮬레이터에서 음성 질문 → 똘똘이 답변까지 동작 확인
- [ ] 실기기 설치: Hi Rokid 앱 "글라스 리소스 패키지 업데이트"가 완료 메시지 없이 멈춤 → Rokid 한국 지원(korea@rokid.com) 문의 대상. ADB 설치가 되면 우회 가능.
- [ ] 실기기에서 한국어 음성 인식(`ko-KR`), 한국어 낭독 품질 (기기 TTS 목소리는 중국어·영어뿐)
- [ ] "하이 로키드, 똘똘이한테 ○○ 물어봐" → `question` 값 전달 여부
- [ ] 화면이 열린 상태에서 "Hi Rokid" 호출을 똘똘이가 받는지 (`onVoiceWakeup`)
- [ ] 대화 카드(`_current`) ↔ 전체 화면(`_blank`) 전환 동작
