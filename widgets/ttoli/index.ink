<script def>
{
  "widget": { "family": "1x2" }
}
</script>

<script setup>
// 홈 화면 상주(persistent) 위젯: 탭하면 바로 똘똘이에게 묻고 짧은 답을 보여 준다.
// 위젯에서는 페이지를 열 수 없으므로(window.open은 위젯 전용) 질문·답변을 위젯 안에서 처리한다.
import { createListener } from '../../lib/speech.js';
import { ask } from '../../lib/hermes.js';
import config from '../../config.js';

const LISTEN_TIMEOUT_MS = 15000;
const MAX_CHARS = 60;

const STATUS = {
  idle: '탭해서 질문',
  listening: '● 듣고 있어요',
  thinking: '● 생각 중',
  answer: '탭해서 다시 질문',
  error: '탭해서 다시 시도',
};

function clip(text) {
  const t = String(text || '').replace(/\s+/g, ' ').trim();
  return t.length > MAX_CHARS ? `${t.slice(0, MAX_CHARS - 1)}…` : t;
}

export default {
  data: {
    state: 'idle',
    status: STATUS.idle,
    line: '무엇이든 물어보세요',
  },

  onCreate() {
    this.alive = true;
  },

  onDetach() {
    this.stopListening();
    if (this.data.state === 'listening') this.show('idle');
  },

  onDestroy() {
    this.alive = false;
    this.stopListening();
  },

  show(state, line) {
    if (!this.alive) return;
    const patch = { state, status: STATUS[state] };
    if (line !== undefined) patch.line = clip(line);
    this.setData(patch);
  },

  stopListening() {
    clearTimeout(this.listenTimer);
    const voice = this.voice;
    this.voice = null;
    if (voice) voice.abort();
  },

  handleTap() {
    if (this.data.state === 'thinking') return;
    if (this.data.state === 'listening') {
      if (this.voice) this.voice.stop();
      return;
    }
    this.listen();
  },

  listen() {
    const voice = createListener({ lang: config.SPEECH_LANG });
    this.voice = voice;
    this.show('listening', '');
    voice.oninterim = (text) => { if (this.voice === voice && text) this.show('listening', text); };
    voice.onfinal = (text) => {
      if (this.voice !== voice) return;
      this.stopListening();
      this.submit(text);
    };
    voice.onerror = ({ key } = {}) => {
      if (this.voice !== voice) return;
      this.stopListening();
      this.show('error', key === 'notInteractive' ? '지금은 들을 수 없어요' : `음성 인식 오류: ${key || ''}`);
    };
    voice.onend = () => {
      if (this.voice !== voice) return;
      this.stopListening();
      if (this.data.state === 'listening') this.show('idle', '무엇이든 물어보세요');
    };
    this.listenTimer = setTimeout(() => {
      if (this.voice !== voice) return;
      this.stopListening();
      this.show('idle', '무엇이든 물어보세요');
    }, LISTEN_TIMEOUT_MS);
    voice.start();
  },

  async submit(text) {
    this.show('thinking', text);
    try {
      const reply = await ask(text);
      this.show('answer', reply || '(빈 응답)');
      if (config.SPEAK_REPLY && reply && typeof speechSynthesis !== 'undefined' && typeof SpeechSynthesisUtterance !== 'undefined') {
        try { speechSynthesis.speak(new SpeechSynthesisUtterance(reply), 'immediate'); } catch (_) {}
      }
    } catch (error) {
      this.show('error', `연결 오류: ${(error && error.message) || error}`);
    }
  },
};
</script>

<widget>
  <view class="widget" bindtap="handleTap">
    <view class="head">
      <text class="name">똘똘이</text>
      <text class="{{state === 'listening' || state === 'thinking' ? 'status status-busy' : 'status'}}">{{status}}</text>
    </view>
    <text class="line">{{line}}</text>
  </view>
</widget>

<style>
/* monochrome-green: 이름 primary, 본문 72%, 상태 48% */
.widget {
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  border: 1px solid rgba(64, 255, 94, 0.24);
  border-radius: 8px;
}

.head {
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}

.name {
  color: #40ff5e;
  font-size: 14px;
  font-weight: 500;
}

.status {
  color: rgba(64, 255, 94, 0.48);
  font-size: 11px;
}

.status-busy {
  color: #40ff5e;
  animation: pulse 1.6s ease-in-out infinite;
}

@keyframes pulse {
  0% { opacity: 0.48; }
  50% { opacity: 1; }
  100% { opacity: 0.48; }
}

.line {
  color: rgba(64, 255, 94, 0.72);
  font-size: 13px;
  line-height: 18px;
}
</style>
