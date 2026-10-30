# Agent: 똘똘이

- **Description**: 사용자의 개인 AI 비서 "똘똘이"(자택 서버의 hermes agent)를 Rokid Glasses에서 음성으로 부르는 에이전트. 질문을 음성으로 받아 HTTPS 프록시(rokid-hermes-proxy)를 거쳐 hermes에 전달하고, 답을 화면에 표시하고 읽어 준다.

## Pages

- `pages/index` (entry): 열리면 바로 듣기 시작한다. 첫 발화가 끝나면(VAD) 질문을 보낸다. 페이지를 열 때 `question`이 전달되면 듣지 않고 그 질문을 바로 보낸다. 템플 탭(Enter)으로 다시 질문하고, 위/아래로 긴 답변을 스크롤한다. "새 대화"라고 말하면 대화 맥락을 초기화한다.

## Capabilities

- Permissions: `RECORD_AUDIO`
- 음성 인식: `SpeechRecognitionSession` (lib/asr.js, wearer 마이크, VAD 단일 발화)
- 음성 합성: `speechSynthesis` (지원 시)
- 네트워크: `fetch` → `https://rokid-hermes.4ints.com` (`/chat`, `/reset`)
- 저장소: `wx.setStorageSync` (대화 세션 이름)

## Privacy

- 음성은 기기 ASR로만 처리하고, 인식된 텍스트만 사용자 본인의 hermes 서버로 보낸다.
