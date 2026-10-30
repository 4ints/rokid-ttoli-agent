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
  idle: '탭하거나 "Hi Rokid"라고 하면 말할 수 있어요',
  card: '두 번 탭하면 전체 화면에서 대화해요',
  listening: '듣고 있어요',
  thinking: '똘똘이가 생각 중',
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
    // 대화 흐름 카드(_current)에서는 음성 인식을 시작할 수 없다. 처음 알 수 없으면 null.
    this.target = null;
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

  // 카드 → 전체 화면(_blank)으로 바뀌면 바로 듣는다.
  onTargetChanged(target) {
    this.target = target;
    if (target === '_blank' && (this.data.state === 'idle' || this.data.state === 'error') && !this.data.answer) {
      this.listen();
    } else if (target === '_current' && this.voice) {
      this.endListening();
      this.setState('idle', { hint: HINT.card });
    }
  },

  // 똘똘이 화면이 열려 있는 동안 "Hi Rokid"/템플 호출을 똘똘이가 받는다.
  // 카드 모드이거나 답을 기다리는 중이면 호스트 기본 동작(시스템 어시스턴트)을 그대로 둔다.
  onVoiceWakeup(event) {
    if (this.exiting || this.target === '_current' || this.data.state === 'thinking') return;
    if (event && typeof event.preventDefault === 'function') event.preventDefault();
    if (this.data.state === 'listening') return;
    this.listen();
  },

  setState(state, patch = {}) {
    if (this.exiting) return;
    this.setData({ state, hint: HINT[state], busy: state === 'listening' || state === 'thinking', ...patch });
  },

  stopAll() {
    clearTimeout(this.startTimer);
    if (this.voice) {
      this.endListening();
      this.setState('idle');
    }
  },

  listen() {
    if (this.exiting || this.data.state === 'thinking' || this.voice) return;
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
      if (key === 'notInteractive') {
        this.target = '_current';
        this.setState('idle', { hint: HINT.card });
        return;
      }
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

  // speechSynthesis.speak()는 공유 플레이어를 쓰며 cancel()이 없다.
  // 'immediate'로 이전 답변 낭독을 끊고 새 답변을 읽는다. (utterance.lang은 현재 무시됨)
  speak(text) {
    if (!config.SPEAK_REPLY || !text || this.exiting) return;
    if (typeof speechSynthesis === 'undefined' || typeof SpeechSynthesisUtterance === 'undefined') return;
    try {
      speechSynthesis.speak(new SpeechSynthesisUtterance(text), 'immediate');
    } catch (error) {
      console.error('[ttoli] tts failed:', error && error.message);
    }
  },

  // Enter(템플 탭): 듣는 중이면 끝내고, 그 외에는 새로 듣기 시작.
  // ArrowUp/Down(스크롤), Backspace(뒤로)는 기본 동작을 그대로 둔다.
  onKeyUp(event) {
    if (!event || event.code !== 'Enter') return;
    if (this.target === '_current') return; // 카드에서는 호스트 기본 동작(전체 화면 전환 등)을 둔다
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
    <text class="answer" ink:if="{{answer}}">{{answer}}</text>
    <text class="{{busy ? 'hint hint-busy' : 'hint'}}">{{busy ? '● ' : ''}}{{hint}}</text>
  </view>
</page>

<style>
/* monochrome-green 토큰: primary #40ff5e, primary-72 본문, primary-48 보조 */
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
  color: rgba(64, 255, 94, 0.48);
  font-size: 12px;
  line-height: 18px;
  margin-bottom: 10px;
}

.answer {
  color: rgba(64, 255, 94, 0.72);
  font-size: 16px;
  line-height: 24px;
}

.hint {
  margin-top: 14px;
  color: rgba(64, 255, 94, 0.48);
  font-size: 11px;
  line-height: 16px;
}

/* 듣는 중/생각 중: 글자 표시(●)와 함께 하나의 느린 깜빡임으로 상태를 보인다 */
.hint-busy {
  color: #40ff5e;
  animation: pulse 1.6s ease-in-out infinite;
}

@keyframes pulse {
  0% { opacity: 0.48; }
  50% { opacity: 1; }
  100% { opacity: 0.48; }
}

@media (target: _current) {
  .stage {
    min-height: 0;
    padding: 12px;
  }
}
</style>
