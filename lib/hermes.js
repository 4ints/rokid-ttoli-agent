// rokid-hermes-proxy 클라이언트: 대화 한 턴 / 새 대화.
// 세션 이름은 기기 로컬 저장소에 보관해 앱을 다시 열어도 대화 맥락이 이어진다.
import wx from 'wx';
import config from '../config.js';

const SESSION_KEY = 'ttoli.session';

function getSession() {
  try { return wx.getStorageSync(SESSION_KEY) || 'default'; } catch (_) { return 'default'; }
}

function setSession(value) {
  try { wx.setStorageSync(SESSION_KEY, value); } catch (_) {}
}

function requestHeaders() {
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${config.PROXY_TOKEN}`,
  };
  if (config.CF_ACCESS_CLIENT_ID && config.CF_ACCESS_CLIENT_SECRET) {
    headers['CF-Access-Client-Id'] = config.CF_ACCESS_CLIENT_ID;
    headers['CF-Access-Client-Secret'] = config.CF_ACCESS_CLIENT_SECRET;
  }
  return headers;
}

// 기기의 fetch는 5초 뒤 "Request timeout after 5000ms"로 끊긴다(폰 블루투스 중계 포함).
// hermes는 도구를 쓰면 수십 초가 걸리므로 timeout을 지정할 수 있는 wx.request를 쓴다.
function request(path, body) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${config.PROXY_URL}${path}`,
      method: 'POST',
      header: requestHeaders(),
      data: body,
      responseType: 'text',
      dataType: 'json',
      timeout: config.REQUEST_TIMEOUT_MS,
      success: resolve,
      fail: (err) => reject(new Error((err && err.errMsg) || '네트워크 오류')),
    });
  });
}

function parseBody(data) {
  if (data && typeof data === 'object') return data;
  try { return JSON.parse(String(data || '{}')); } catch (_) { return {}; }
}

async function post(path, body) {
  if (!config.PROXY_TOKEN) {
    throw new Error('config.js의 PROXY_TOKEN이 비어 있어요');
  }
  const res = await request(path, body);
  const data = parseBody(res.data);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw new Error(data.error || `서버 오류 (${res.statusCode})`);
  }
  return data;
}

export async function ask(message) {
  const data = await post('/chat', { session: getSession(), message });
  if (data.session) setSession(data.session);
  return data.reply || '';
}

export async function resetConversation() {
  const data = await post('/reset', {});
  if (data.session) setSession(data.session);
}
