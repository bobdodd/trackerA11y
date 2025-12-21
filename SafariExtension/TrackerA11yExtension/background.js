const HTTP_URL = 'http://localhost:9877/element';

function sendMessage(message) {
  fetch(HTTP_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(message)
  }).then(response => {
    if (response.ok) {
      console.log('TrackerA11y: Sent', message.type, 'to bridge');
    }
  }).catch(() => {});
}

const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

browserAPI.runtime.onMessage.addListener((message, sender) => {
  const validTypes = ['focus_change', 'mouse_down', 'mouse_up', 'click', 'hover'];
  if (validTypes.includes(message.type)) {
    console.log('TrackerA11y:', message.type, message.element?.tagName, message.element?.id || '');
    message.tabId = sender.tab?.id;
    message.tabUrl = sender.tab?.url;
    message.frameId = sender.frameId;
    sendMessage(message);
  }
  return false;
});

console.log('TrackerA11y background script loaded');
