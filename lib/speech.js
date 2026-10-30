// 한 번의 발화를 받아 텍스트로 돌려주는 리스너.
//
// 1순위: 호스트가 마이크를 처리하는 `SpeechRecognition` (capabilities 샘플과 같은 방식).
//        대화 흐름 카드(_current)와 Studio 시뮬레이터에서도 동작한다.
// 2순위: `SpeechRecognitionSession` + 마이크 PCM 직접 처리 (lib/asr.js).
//        SpeechRecognition이 없거나 지원되지 않을 때만 사용한다.
//
// 콜백: oninterim(text), onfinal(text), onerror({ key, message }), onend()
import { createRecognizer } from './asr.js';

const UNSUPPORTED_ERRORS = ['not-allowed', 'service-not-allowed', 'language-not-supported', 'audio-capture', 'network'];

function transcriptOf(event) {
  const results = event && event.results ? event.results : [];
  let text = '';
  let hasFinal = false;
  for (let i = 0; i < results.length; i += 1) {
    const alt = results[i] && results[i][0];
    if (alt && alt.transcript) text += alt.transcript;
    if (results[i] && results[i].isFinal) hasFinal = true;
  }
  return { text: text.trim(), hasFinal };
}

export function createListener({ lang }) {
  const api = { start, stop, abort, mode: '' };
  let recognition = null;
  let session = null;
  let finished = false;
  let latest = '';

  const finish = (text) => {
    if (finished) return;
    finished = true;
    if (text && api.onfinal) api.onfinal(text);
    if (api.onend) api.onend();
  };

  function startSession() {
    api.mode = 'session';
    session = createRecognizer({
      SpeechRecognitionSession: typeof SpeechRecognitionSession === 'undefined' ? null : SpeechRecognitionSession,
      captureMode: 'wearer',
      vad: true,
      lang,
    });
    session.oninterim = ({ text } = {}) => { if (text && api.oninterim) api.oninterim(text); };
    session.onsegment = ({ text } = {}) => {
      session.abort();
      finish(text);
    };
    session.onerror = (payload = {}) => {
      if (finished) return;
      finished = true;
      if (api.onerror) api.onerror(payload);
      if (api.onend) api.onend();
    };
    session.onend = () => finish(latest);
    session.start();
  }

  function startRecognition() {
    api.mode = 'recognition';
    recognition = new SpeechRecognition();
    recognition.lang = lang;
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
      const { text, hasFinal } = transcriptOf(event);
      if (!text) return;
      latest = text;
      if (api.oninterim) api.oninterim(text);
      if (hasFinal) {
        try { recognition.stop(); } catch (_) {}
      }
    };
    recognition.onerror = (event = {}) => {
      const key = event.error || 'recognitionFailed';
      console.error('[ttoli] SpeechRecognition error:', key, event.message || '');
      if (finished) return;
      // 이 환경에서 SpeechRecognition을 쓸 수 없으면 PCM 파이프라인으로 넘어간다.
      if (UNSUPPORTED_ERRORS.includes(key) && typeof SpeechRecognitionSession !== 'undefined') {
        recognition.onend = null;
        recognition = null;
        startSession();
        return;
      }
      if (key === 'no-speech' || key === 'aborted') return; // onend에서 조용히 끝낸다
      finished = true;
      if (api.onerror) api.onerror({ key, message: event.message || '' });
      if (api.onend) api.onend();
    };
    recognition.onend = () => finish(latest);
    recognition.start();
  }

  function start() {
    try {
      if (typeof SpeechRecognition !== 'undefined') startRecognition();
      else startSession();
    } catch (error) {
      if (api.mode === 'recognition' && typeof SpeechRecognitionSession !== 'undefined') {
        recognition = null;
        startSession();
        return;
      }
      finished = true;
      if (api.onerror) api.onerror({ key: 'startFailed', message: (error && error.message) || String(error) });
      if (api.onend) api.onend();
    }
  }

  // 말하기를 끝냈다고 알림: 지금까지 들은 내용으로 마무리한다.
  function stop() {
    if (recognition) { try { recognition.stop(); } catch (_) {} }
    if (session) session.stop();
  }

  // 결과 없이 조용히 중단.
  function abort() {
    finished = true;
    if (recognition) {
      recognition.onresult = null;
      recognition.onerror = null;
      recognition.onend = null;
      try { recognition.abort(); } catch (_) {}
      recognition = null;
    }
    if (session) { session.abort(); session = null; }
  }

  return api;
}
