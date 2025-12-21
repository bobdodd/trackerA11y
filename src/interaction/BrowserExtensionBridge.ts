import { WebSocketServer, WebSocket } from 'ws';
import { createServer, IncomingMessage, ServerResponse } from 'http';
import { EventEmitter } from 'events';

const BRIDGE_PORT = 9876;
const HTTP_PORT = 9877;

export interface BrowserElementDetails {
  tagName: string;
  id?: string;
  className?: string;
  classList?: string[];
  type?: string;
  name?: string;
  value?: string;
  placeholder?: string;
  href?: string;
  src?: string;
  alt?: string;
  title?: string;
  textContent?: string;
  innerText?: string;
  role?: string;
  ariaLabel?: string;
  ariaDescribedby?: string;
  ariaLabelledby?: string;
  ariaExpanded?: string;
  ariaHaspopup?: string;
  ariaPressed?: string;
  ariaSelected?: string;
  ariaChecked?: string;
  ariaDisabled?: string;
  ariaHidden?: string;
  ariaLive?: string;
  ariaAtomic?: string;
  ariaBusy?: string;
  ariaRequired?: string;
  ariaInvalid?: string;
  ariaCurrent?: string;
  ariaControls?: string;
  ariaOwns?: string;
  ariaFlowto?: string;
  ariaValuenow?: string;
  ariaValuemin?: string;
  ariaValuemax?: string;
  ariaValuetext?: string;
  tabIndex?: number;
  disabled?: boolean;
  readOnly?: boolean;
  required?: boolean;
  checked?: boolean;
  selected?: boolean;
  contentEditable?: string;
  isContentEditable?: boolean;
  draggable?: boolean;
  hidden?: boolean;
  inputMode?: string;
  autocomplete?: string;
  pattern?: string;
  minLength?: number;
  maxLength?: number;
  min?: string;
  max?: string;
  step?: string;
  form?: string;
  formAction?: string;
  formMethod?: string;
  xpath?: string;
  allAttributes?: Record<string, string>;
  computedStyles?: Record<string, string>;
  outerHTML?: string;
  bounds?: {
    x: number;
    y: number;
    width: number;
    height: number;
    viewportX: number;
    viewportY: number;
    screenX: number;
    screenY: number;
  };
  parentURL?: string;
  parentTitle?: string;
  frameId?: string;
  timestamp?: number;
}

export interface BrowserFocusEvent {
  type: 'focus_change';
  trigger: 'focusin' | 'click' | 'tab' | 'initial';
  element: BrowserElementDetails;
  url: string;
  title: string;
  tabId?: number;
  tabUrl?: string;
  frameId?: number;
}

export interface BrowserElementEvent {
  type: 'mouse_down' | 'mouse_up' | 'click' | 'hover';
  element: BrowserElementDetails;
  url: string;
  title: string;
  button?: number;
  clientX?: number;
  clientY?: number;
  screenX?: number;
  screenY?: number;
  tabId?: number;
  tabUrl?: string;
  frameId?: number;
}

export class BrowserExtensionBridge extends EventEmitter {
  private wss: WebSocketServer | null = null;
  private httpServer: ReturnType<typeof createServer> | null = null;
  private clients: Set<WebSocket> = new Set();
  private isRunning = false;
  private lastEventSignature = '';

  async start(): Promise<void> {
    if (this.isRunning) return;

    await this.startWebSocketServer();
    await this.startHttpServer();
    
    this.isRunning = true;
  }

  private async startWebSocketServer(): Promise<void> {
    return new Promise((resolve) => {
      try {
        this.wss = new WebSocketServer({ port: BRIDGE_PORT });

        this.wss.on('listening', () => {
          console.log(`🌐 Browser extension bridge (WebSocket) on ws://localhost:${BRIDGE_PORT}`);
          resolve();
        });

        this.wss.on('connection', (ws) => {
          this.clients.add(ws);
          console.log('🔗 Browser extension connected (WebSocket)');

          ws.on('message', (data) => {
            try {
              const message = JSON.parse(data.toString());
              this.handleMessage(message);
            } catch (e) {}
          });

          ws.on('close', () => {
            this.clients.delete(ws);
          });

          ws.on('error', () => {
            this.clients.delete(ws);
          });
        });

        this.wss.on('error', () => {
          resolve();
        });
      } catch (error) {
        resolve();
      }
    });
  }

  private async startHttpServer(): Promise<void> {
    return new Promise((resolve) => {
      this.httpServer = createServer((req: IncomingMessage, res: ServerResponse) => {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

        if (req.method === 'OPTIONS') {
          res.writeHead(204);
          res.end();
          return;
        }

        if (req.method === 'POST' && (req.url === '/focus' || req.url === '/element')) {
          let body = '';
          req.on('data', chunk => { body += chunk; });
          req.on('end', () => {
            try {
              const message = JSON.parse(body);
              this.handleMessage(message);
              res.writeHead(200, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ ok: true }));
            } catch (e) {
              res.writeHead(400);
              res.end('Invalid JSON');
            }
          });
        } else {
          res.writeHead(404);
          res.end();
        }
      });

      this.httpServer.on('error', () => {
        resolve();
      });

      this.httpServer.listen(HTTP_PORT, () => {
        console.log(`🌐 Browser extension bridge (HTTP) on http://localhost:${HTTP_PORT}`);
        resolve();
      });
    });
  }

  private handleMessage(message: any): void {
    const validTypes = ['focus_change', 'mouse_down', 'mouse_up', 'click', 'hover'];
    if (!validTypes.includes(message.type)) {
      return;
    }

    const signature = this.createSignature(message);
    if (signature === this.lastEventSignature) {
      return;
    }
    this.lastEventSignature = signature;

    if (message.type === 'focus_change') {
      console.log(`🌐 Bridge: focus_change on <${message.element?.tagName}> id=${message.element?.id || ''}`);
      const event: BrowserFocusEvent = {
        type: 'focus_change',
        trigger: message.trigger || 'focusin',
        element: message.element,
        url: message.url,
        title: message.title,
        tabId: message.tabId,
        tabUrl: message.tabUrl,
        frameId: message.frameId
      };
      this.emit('browserFocus', event);
    } else {
      console.log(`🌐 Bridge: ${message.type} on <${message.element?.tagName}> id=${message.element?.id || ''} xpath=${message.element?.xpath || ''}`);
      const event: BrowserElementEvent = {
        type: message.type,
        element: message.element,
        url: message.url,
        title: message.title,
        button: message.button,
        clientX: message.clientX,
        clientY: message.clientY,
        screenX: message.screenX,
        screenY: message.screenY,
        tabId: message.tabId,
        tabUrl: message.tabUrl,
        frameId: message.frameId
      };
      this.emit('browserElement', event);
    }
  }

  private createSignature(message: any): string {
    const el = message.element || {};
    return `${el.tagName}|${el.id}|${el.className}|${el.bounds?.x}|${el.bounds?.y}|${message.url}`;
  }

  async stop(): Promise<void> {
    if (!this.isRunning) return;

    for (const client of this.clients) {
      client.close();
    }
    this.clients.clear();

    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }

    if (this.httpServer) {
      this.httpServer.close();
      this.httpServer = null;
    }

    this.isRunning = false;
    console.log('🔌 Browser extension bridge stopped');
  }

  get connected(): boolean {
    return this.clients.size > 0;
  }
}
