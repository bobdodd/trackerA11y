const HTTP_URL = 'http://localhost:9877/element';
const SCREENSHOT_CHECK_URL = 'http://localhost:9877/screenshot-request';

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

async function checkForScreenshotRequest() {
  try {
    const response = await fetch(SCREENSHOT_CHECK_URL);
    if (response.ok) {
      const data = await response.json();
      if (data.requestScreenshot) {
        console.log('TrackerA11y: Screenshot requested, capturing...');
        await captureAndSendFullPage(data.requestId);
      }
    }
  } catch (e) {}
}

async function captureAndSendFullPage(requestId) {
  const browserAPI = typeof browser !== 'undefined' ? browser : chrome;
  
  try {
    const tabs = await browserAPI.tabs.query({ active: true, currentWindow: true });
    if (tabs.length === 0) {
      console.log('TrackerA11y: No active tab');
      return;
    }
    
    const tab = tabs[0];
    console.log('TrackerA11y: Sending capture request to tab', tab.id);
    
    browserAPI.tabs.sendMessage(tab.id, { type: 'capture_full_page' }, async (response) => {
      if (response && response.success) {
        console.log('TrackerA11y: Got screenshot data, sending to bridge');
        await fetch('http://localhost:9877/screenshot-data', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            requestId: requestId,
            dataUrl: response.dataUrl
          })
        });
      } else {
        console.log('TrackerA11y: Screenshot capture failed', response?.error);
      }
    });
  } catch (e) {
    console.log('TrackerA11y: Error capturing screenshot', e);
  }
}

setInterval(checkForScreenshotRequest, 500);

const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

browserAPI.runtime.onMessage.addListener((message, sender) => {
  const validTypes = ['focus_change', 'mouse_down', 'mouse_up', 'click', 'hover'];
  if (validTypes.includes(message.type)) {
    console.log('TrackerA11y:', message.type, message.element?.tagName, message.element?.id || '');
    
    message.browser = {
      name: 'Safari',
      windowId: sender.tab?.windowId,
      tabId: sender.tab?.id,
      tabIndex: sender.tab?.index,
      tabUrl: sender.tab?.url,
      tabTitle: sender.tab?.title,
      frameId: sender.frameId,
      incognito: sender.tab?.incognito || false
    };
    
    message.tabId = sender.tab?.id;
    message.tabUrl = sender.tab?.url;
    message.frameId = sender.frameId;
    
    sendMessage(message);
  }
  return false;
});

console.log('TrackerA11y background script loaded');
