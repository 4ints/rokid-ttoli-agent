// 한 번의 발화를 받아 텍스트로 돌려주는 리스너.
//
// 1순위: 호스트가 마이크를 처리하는 `SpeechRecognition`.
//        Ink는 최종 결과만 전달하므로 interimResults는 쓰지 않는다(기본값 false).
// 2순위: `SpeechRecognitionSession` + 마이크 PCM 직접 처리 (lib/asr.js).
//        SpeechRecognition이 없거나 호스트가 음성 인식 기능을 제공하지 않을 때만 사용한다.
//
// 대화 흐름 카드(_current)처럼 상호작용할 수 없는 화면에서는 start()가 InvalidStateError를 내므로
// 대체 경로로 넘어가지 않고 key 'notInteractive'로 알린다.
//
// 콜백: oninterim(text), onfinal(text), onerror({ key, message }), onend()
import { createRecognizer } from './asr.js';

const FALLBACK_ERRORS = ['service-not-allowed', 'audio-capture', 'network'];

function transcriptOf(event) {
  const results = event && event.results ? event.results : [];
  let text = '';
  for (let i = 0; i < results.length; i += 1) {
    const alt = results[i] && results[i][0];
    if (alt && alt.transcript) text += alt.transcript;
  }
  return text.trim();
}

function isNotInteractive(error) {
  return Boolean(error && (error.name === 'InvalidStateError' || /interactive/i.test(error.message || '')));
}

export function createListener({ lang }) {
  const api = { start, stop, abort, mode: '' };
  let recognition = null;
  let session = null;
  let finished = false;
  let latest = '';

  const fail = (key, message) => {
    if (finished) return;
    finished = true;
    if (api.onerror) api.onerror({ key, message: message || '' });
    if (api.onend) api.onend();
  };

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
    session.onerror = ({ key, message } = {}) => fail(key, message);
    session.onend = () => finish(latest);
    session.start();
  }

  function dropRecognition() {
    if (!recognition) return;
    recognition.onresult = null;
    recognition.onerror = null;
    recognition.onend = null;
    recognition = null;
  }

  function startRecognition(recognitionLang) {
    api.mode = 'recognition';
    recognition = new SpeechRecognition();
    recognition.lang = recognitionLang;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
      const text = transcriptOf(event);
      if (!text) return;
      latest = text;
      if (api.oninterim) api.oninterim(text);
    };
    recognition.onerror = (event = {}) => {
      const key = event.error || 'recognitionFailed';
      console.error('[ttoli] SpeechRecognition error:', key, event.message || '');
      if (finished) return;
      // 요청한 언어를 지원하지 않으면 호스트 기본 언어로 한 번 더 시도한다.
      if (key === 'language-not-supported' && recognitionLang) {
        dropRecognition();
        startRecognition('');
        return;
      }
      if (FALLBACK_ERRORS.includes(key) && typeof SpeechRecognitionSession !== 'undefined') {
        dropRecognition();
        startSession();
        return;
      }
      if (key === 'no-speech' || key === 'aborted') return; // onend에서 조용히 끝낸다
      fail(key, event.message);
    };
    recognition.onend = () => finish(latest);
    recognition.start();
  }

  function start() {
    try {
      if (typeof SpeechRecognition !== 'undefined') startRecognition(lang);
      else startSession();
    } catch (error) {
      if (isNotInteractive(error)) {
        dropRecognition();
        fail('notInteractive', error.message);
        return;
      }
      if (api.mode === 'recognition' && typeof SpeechRecognitionSession !== 'undefined') {
        dropRecognition();
        startSession();
        return;
      }
      fail('startFailed', (error && error.message) || String(error));
    }
  }

  // 말하기를 끝냈다고 알림: 호스트가 최종 결과를 확정한다.
  function stop() {
    if (recognition) { try { recognition.stop(); } catch (_) {} }
    if (session) session.stop();
  }

  // 결과 없이 조용히 중단.
  function abort() {
    finished = true;
    if (recognition) {
      const r = recognition;
      dropRecognition();
      try { r.abort(); } catch (_) {}
    }
    if (session) { session.abort(); session = null; }
  }

  return api;
}
