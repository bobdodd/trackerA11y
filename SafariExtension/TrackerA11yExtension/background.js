const HTTP_URL = 'http://localhost:9877/focus';

function sendMessage(message) {
  fetch(HTTP_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(message)
  }).then(response => {
    if (response.ok) {
      console.log('TrackerA11y: Sent to bridge');
    }
  }).catch(() => {});
}

const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

browserAPI.runtime.onMessage.addListener((message, sender) => {
  if (message.type === 'focus_change') {
    console.log('TrackerA11y FOCUS:', message.element?.tagName, message.element?.id || '', message.trigger);
    message.tabId = sender.tab?.id;
    message.tabUrl = sender.tab?.url;
    message.frameId = sender.frameId;
    sendMessage(message);
  }
  return false;
});

console.log('TrackerA11y background script loaded');
