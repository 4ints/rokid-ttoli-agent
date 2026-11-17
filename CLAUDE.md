# 똘똘이 (Rokid Glasses AIUI agent)

개발 방법과 현재 상태는 `DEVELOPMENT.md`, 에이전트 설명은 `AGENTS.md`를 본다.

## 규칙

- 이 저장소는 **공개**다. `config.js`의 `PROXY_TOKEN`, `CF_ACCESS_*` 는 항상 빈 값으로 커밋한다.
  토큰은 `%USERPROFILE%\.rokid-hermes\env` 에만 두고, 패키징/설치는 `scripts/pack-local.ps1` 로 한다.
- AIUI API·컴포넌트·WXSS는 추측하지 말고 `aiui-dev` 스킬의 references에서 확인한다
  (설치: `DEVELOPMENT.md` 1절). 완료 전에는 스킬의 `references/checklist.md`를 적용한다.
- 기기에서 확인된 동작(Ink 런타임 0.19 기준):
  - `SpeechRecognition`은 최종 결과만 준다(`interimResults` 미지원).
  - 대화 카드(`_current`)에서는 마이크 PCM(AudioContext) 경로가 동작하지 않는다.
  - `speechSynthesis.cancel()`은 없고 `utterance.lang`은 무시된다.
  - Studio 시뮬레이터의 네트워크 요청은 Rokid 중계(싱가포르)를 거쳐 서버에 도착한다.
- 화면 디자인은 monochrome-green 규격(480×352, `#40ff5e` 단색, 본문 72%·보조 48%)을 따른다.
- 서버(hermes, 프록시, 터널)는 이 저장소에 없다. 서버 동작을 바꿔야 하면 사용자에게 알린다.
