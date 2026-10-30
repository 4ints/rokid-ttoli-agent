# 똘똘이 — Rokid Glasses AIUI agent

Rokid Glasses에서 음성으로 개인 AI 비서 "똘똘이"(hermes agent)를 호출하는 AIUI 에이전트.

- 열리면 바로 듣고, 말이 끝나면(VAD) 질문을 보내 답을 화면에 표시하고 읽어 준다.
- 템플 탭: 다시 질문 · 위/아래: 스크롤 · "새 대화": 맥락 초기화
- 서버(인증 프록시)는 이 저장소에 포함되지 않는다.

## AIUI Studio에서 사용
1. New Agent ▾ → Import from GitHub → 이 저장소 URL
2. Code 탭에서 `config.js`의 `PROXY_TOKEN`을 채운다 (토큰은 저장소에 올리지 않음)
3. Simulator로 확인 → Package AIX → Hi Rokid 앱에서 Update glasses resource

`lib/asr.js`는 [jsar-project/AIUI](https://github.com/jsar-project/AIUI) 샘플(Apache-2.0)을 수정한 것이다.
