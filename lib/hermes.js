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

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('응답 시간이 초과됐어요')), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
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

async function post(path, body) {
  if (!config.PROXY_TOKEN) {
    throw new Error('config.js의 PROXY_TOKEN이 비어 있어요');
  }
  const response = await withTimeout(fetch(`${config.PROXY_URL}${path}`, {
    method: 'POST',
    headers: requestHeaders(),
    body: JSON.stringify(body),
  }), config.REQUEST_TIMEOUT_MS);
  let data = {};
  try { data = await response.json(); } catch (_) {}
  if (!response.ok) {
    throw new Error(data.error || `서버 오류 (${response.status})`);
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
