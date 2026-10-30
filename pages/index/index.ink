<script type="application/json" def>
{
  "navigationBarTitleText": "똘똘이",
  "description": "사용자의 개인 AI 비서 '똘똘이'(hermes agent)에게 질문하고 답을 받는다. 사용자가 똘똘이에게 묻거나 부탁하라고 하면 이 페이지를 연다.",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "question": {
          "type": "string",
          "description": "똘똘이에게 전달할 사용자의 질문이나 요청 원문. 없으면 페이지가 열린 뒤 음성으로 듣는다."
        }
      }
    }
  },
  "disableScroll": false
}
</script>

<script setup>
import { createListener } from '../../lib/speech.js';
import { ask, resetConversation } from '../../lib/hermes.js';
import config from '../../config.js';

const LISTEN_TIMEOUT_MS = 12000;
const RESET_PATTERN = /^(새\s*대화|대화\s*초기화|처음부터)/;

const HINT = {
  idle: '템플을 탭하면 말할 수 있어요',
  listening: '듣고 있어요…',
  thinking: '똘똘이가 생각 중…',
  answer: '탭: 이어서 질문 · 위/아래: 스크롤',
  error: '탭해서 다시 시도',
};

export default {
  data: {
    state: 'idle',
    busy: false,
    hint: HINT.idle,
    question: '',
    answer: '',
  },

  onLoad(query) {
    this.loadedAt = Date.now();
    this.exiting = false;
    const question = query && typeof query.question === 'string' ? query.question.trim() : '';
    if (question) {
      this.submit(question);
    } else {
      // 페이지를 연 탭/음성의 꼬리 이벤트와 겹치지 않도록 잠깐 뒤에 듣기 시작
      this.startTimer = setTimeout(() => this.listen(), 600);
    }
  },

  onHide() {
    this.stopAll();
  },

  onUnload() {
    this.exiting = true;
    this.stopAll();
  },

  setState(state, patch = {}) {
    if (this.exiting) return;
    this.setData({ state, hint: HINT[state], busy: state === 'listening' || state === 'thinking', ...patch });
  },

  stopAll() {
    clearTimeout(this.startTimer);
    clearTimeout(this.listenTimer);
    if (this.voice) { this.voice.abort(); this.voice = null; }
    this.cancelSpeech();
  },

  listen() {
    if (this.exiting || this.data.state === 'thinking' || this.voice) return;
    this.cancelSpeech();
    this.setState('listening', { question: '' });

    const voice = createListener({ lang: config.SPEECH_LANG });
    this.voice = voice;
    voice.oninterim = (text) => {
      if (this.voice === voice && text) this.setData({ question: text });
    };
    // 발화가 끝나면 바로 질문으로 보낸다.
    voice.onfinal = (text) => {
      if (this.voice !== voice || !text) return;
      this.endListening();
      this.submit(text);
    };
    voice.onerror = ({ key, message } = {}) => {
      if (this.voice !== voice) return;
      this.endListening();
      this.setState('error', { answer: `음성 인식 오류: ${key || ''} ${message || ''}`.trim() });
    };
    voice.onend = () => {
      if (this.voice !== voice) return;
      this.endListening();
      if (this.data.state === 'listening') this.setState('idle');
    };
    this.listenTimer = setTimeout(() => {
      if (this.voice !== voice) return;
      this.endListening();
      this.setState('idle');
    }, LISTEN_TIMEOUT_MS);
    voice.start();
  },

  endListening() {
    clearTimeout(this.listenTimer);
    const voice = this.voice;
    this.voice = null;
    if (voice) voice.abort();
  },

  async submit(text) {
    if (RESET_PATTERN.test(text)) {
      this.setState('thinking', { question: text, answer: '' });
      try {
        await resetConversation();
        this.setState('answer', { answer: '새 대화를 시작했어요.' });
      } catch (error) {
        this.setState('error', { answer: `초기화 실패: ${error.message || error}` });
      }
      return;
    }

    this.setState('thinking', { question: text, answer: '' });
    try {
      const reply = await ask(text);
      this.setState('answer', { answer: reply || '(빈 응답)' });
      this.speak(reply);
    } catch (error) {
      this.setState('error', { answer: `연결 오류: ${error.message || error}` });
    }
  },

  speak(text) {
    if (!config.SPEAK_REPLY || !text || this.exiting) return;
    if (typeof speechSynthesis === 'undefined' || typeof SpeechSynthesisUtterance === 'undefined') return;
    try {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = config.SPEECH_LANG;
      speechSynthesis.speak(utterance);
    } catch (error) {
      console.error('[ttoli] tts failed:', error && error.message);
    }
  },

  cancelSpeech() {
    try {
      if (typeof speechSynthesis !== 'undefined' && typeof speechSynthesis.cancel === 'function') {
        speechSynthesis.cancel();
      }
    } catch (_) {}
  },

  // Enter(템플 탭): 듣는 중이면 끝내고, 그 외에는 새로 듣기 시작.
  // ArrowUp/Down(스크롤), Backspace(뒤로)는 기본 동작을 그대로 둔다.
  onKeyUp(event) {
    if (!event || event.code !== 'Enter') return;
    if (typeof event.preventDefault === 'function') event.preventDefault();
    if (Date.now() - (this.loadedAt || 0) < 1000) return;
    if (this.data.state === 'listening') {
      if (this.voice) this.voice.stop();
      return;
    }
    this.listen();
  },
};
</script>

<page>
  <view class="stage">
    <text class="question" ink:if="{{question}}">“{{question}}”</text>
    <view class="dots" ink:if="{{busy}}">
      <text class="dot">●</text><text class="dot dot2">●</text><text class="dot dot3">●</text>
    </view>
    <text class="answer" ink:if="{{answer}}">{{answer}}</text>
    <text class="hint">{{hint}}</text>
  </view>
</page>

<style>
.stage {
  width: 100%;
  min-height: 100vh;
  box-sizing: border-box;
  padding: 20px 16px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.question {
  color: rgba(64, 255, 94, 0.6);
  font-size: 15px;
  line-height: 22px;
  margin-bottom: 12px;
}

.answer {
  color: #40FF5E;
  font-size: 18px;
  line-height: 28px;
}

.dots {
  display: flex;
  flex-direction: row;
  margin-bottom: 12px;
}

.dot {
  color: #40FF5E;
  font-size: 12px;
  margin-right: 6px;
  animation: blink 1.2s infinite;
}

.dot2 { animation-delay: 0.2s; }
.dot3 { animation-delay: 0.4s; }

@keyframes blink {
  0% { opacity: 0.2; }
  50% { opacity: 1; }
  100% { opacity: 0.2; }
}

.hint {
  margin-top: 16px;
  color: rgba(64, 255, 94, 0.45);
  font-size: 13px;
  line-height: 18px;
}
</style>
