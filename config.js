// 개인용 설정. 이 저장소는 공개이므로 토큰은 비워 두고,
// AIUI Studio로 가져온 뒤 Code 탭에서 PROXY_TOKEN(필수)과 CF_ACCESS_*(사용 시)를 채운다.
// 로컬 패키징은 서버의 tools/pack-local.sh 가 토큰을 주입한 임시 복사본으로 한다.
export default {
  PROXY_URL: 'https://rokid-hermes.4ints.com',
  PROXY_TOKEN: '',
  // 안경 ASR/TTS 언어. 기기가 ko-KR을 지원하지 않으면 'zh-CN' 또는 'en-US'로 바꿔 시험한다.
  SPEECH_LANG: 'ko-KR',
  // 답변을 음성으로 읽을지 여부
  SPEAK_REPLY: true,
  REQUEST_TIMEOUT_MS: 120000,
  // Cloudflare Access 서비스 토큰. 비어 있으면 헤더를 보내지 않는다.
  CF_ACCESS_CLIENT_ID: '',
  CF_ACCESS_CLIENT_SECRET: '',
};
