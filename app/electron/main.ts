/**
 * TrackerA11y Electron Main Process
 * Manages the native desktop application and TrackerA11y Core integration
 */

import { app, BrowserWindow, Menu, ipcMain, dialog, shell } from 'electron';
import * as path from 'path';
import { TrackerA11yCore } from '../../src/core/TrackerA11yCore';
import { MongoDBStore } from '../../src/database/MongoDBStore';
import { TrackerA11yConfig, TimestampedEvent } from '../../src/types';

interface AppState {
  tracker: TrackerA11yCore | null;
  database: MongoDBStore | null;
  isTracking: boolean;
  currentSessionId: string | null;
}

class TrackerA11yApp {
  private mainWindow: BrowserWindow | null = null;
  private state: AppState = {
    tracker: null,
    database: null,
    isTracking: false,
    currentSessionId: null
  };

  constructor() {
    // Handle app lifecycle
    app.whenReady().then(() => {
      this.createMainWindow();
      this.setupMenu();
      this.setupIPC();
      this.initializeServices();
    });

    app.on('window-all-closed', () => {
      if (process.platform !== 'darwin') {
        this.cleanup().then(() => app.quit());
      }
    });

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        this.createMainWindow();
      }
    });

    app.on('before-quit', () => {
      this.cleanup();
    });
  }

  /**
   * Create the main application window
   */
  private createMainWindow(): void {
    this.mainWindow = new BrowserWindow({
      width: 1200,
      height: 800,
      minWidth: 800,
      minHeight: 600,
      titleBarStyle: 'hiddenInset',
      trafficLightPosition: { x: 20, y: 20 },
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        enableRemoteModule: false,
        preload: path.join(__dirname, 'preload.js')
      }
    });

    // Load the React app
    const isDev = process.env.NODE_ENV === 'development';
    if (isDev) {
      this.mainWindow.loadURL('http://localhost:3000');
      // this.mainWindow.webContents.openDevTools();
    } else {
      this.mainWindow.loadFile(path.join(__dirname, '../build/index.html'));
    }

    this.mainWindow.on('closed', () => {
      this.mainWindow = null;
    });

    // Handle external links
    this.mainWindow.webContents.setWindowOpenHandler(({ url }) => {
      shell.openExternal(url);
      return { action: 'deny' };
    });
  }

  /**
   * Setup application menu
   */
  private setupMenu(): void {
    const template = [
      {
        label: 'TrackerA11y',
        submenu: [
          {
            label: 'About TrackerA11y',
            click: () => this.showAboutDialog()
          },
          { type: 'separator' },
          {
            label: 'Preferences...',
            accelerator: 'Cmd+,',
            click: () => this.showPreferences()
          },
          { type: 'separator' },
          {
            label: 'Quit TrackerA11y',
            accelerator: 'Cmd+Q',
            click: () => app.quit()
          }
        ]
      },
      {
        label: 'Session',
        submenu: [
          {
            label: 'Start Recording',
            accelerator: 'Cmd+R',
            click: () => this.startTracking()
          },
          {
            label: 'Stop Recording',
            accelerator: 'Cmd+S',
            click: () => this.stopTracking()
          },
          { type: 'separator' },
          {
            label: 'New Session',
            accelerator: 'Cmd+N',
            click: () => this.newSession()
          },
          {
            label: 'Export Session...',
            accelerator: 'Cmd+E',
            click: () => this.exportSession()
          }
        ]
      },
      {
        label: 'View',
        submenu: [
          {
            label: 'Reload',
            accelerator: 'Cmd+R',
            click: () => this.mainWindow?.reload()
          },
          {
            label: 'Force Reload',
            accelerator: 'Cmd+Shift+R',
            click: () => this.mainWindow?.webContents.reloadIgnoringCache()
          },
          {
            label: 'Developer Tools',
            accelerator: 'Cmd+Option+I',
            click: () => this.mainWindow?.webContents.toggleDevTools()
          },
          { type: 'separator' },
          {
            label: 'Actual Size',
            accelerator: 'Cmd+0',
            click: () => this.mainWindow?.webContents.setZoomLevel(0)
          },
          {
            label: 'Zoom In',
            accelerator: 'Cmd+Plus',
            click: () => {
              const currentZoom = this.mainWindow?.webContents.getZoomLevel() || 0;
              this.mainWindow?.webContents.setZoomLevel(currentZoom + 1);
            }
          },
          {
            label: 'Zoom Out',
            accelerator: 'Cmd+-',
            click: () => {
              const currentZoom = this.mainWindow?.webContents.getZoomLevel() || 0;
              this.mainWindow?.webContents.setZoomLevel(currentZoom - 1);
            }
          }
        ]
      },
      {
        label: 'Window',
        submenu: [
          {
            label: 'Minimize',
            accelerator: 'Cmd+M',
            role: 'minimize'
          },
          {
            label: 'Close',
            accelerator: 'Cmd+W',
            role: 'close'
          }
        ]
      },
      {
        label: 'Help',
        submenu: [
          {
            label: 'Documentation',
            click: () => shell.openExternal('https://github.com/your-repo/trackera11y')
          },
          {
            label: 'Report Issue',
            click: () => shell.openExternal('https://github.com/your-repo/trackera11y/issues')
          }
        ]
      }
    ];

    const menu = Menu.buildFromTemplate(template as any);
    Menu.setApplicationMenu(menu);
  }

  /**
   * Setup IPC communication with renderer
   */
  private setupIPC(): void {
    // Tracker control
    ipcMain.handle('tracker:start', () => this.startTracking());
    ipcMain.handle('tracker:stop', () => this.stopTracking());
    ipcMain.handle('tracker:status', () => ({
      isTracking: this.state.isTracking,
      sessionId: this.state.currentSessionId
    }));

    // Database operations
    ipcMain.handle('database:connect', (_, connectionString: string) => 
      this.connectDatabase(connectionString));
    ipcMain.handle('database:disconnect', () => this.disconnectDatabase());
    ipcMain.handle('database:status', () => ({
      connected: this.state.database?.isConnectedToDatabase() || false,
      currentSession: this.state.database?.getCurrentSession()
    }));

    // Session management
    ipcMain.handle('session:create', (_, metadata: any) => this.createSession(metadata));
    ipcMain.handle('session:list', () => this.listSessions());
    ipcMain.handle('session:export', (_, sessionId: string) => this.exportSessionData(sessionId));

    // Event queries
    ipcMain.handle('events:query', (_, filter: any) => this.queryEvents(filter));
    ipcMain.handle('events:aggregation', (_, sessionId: string) => 
      this.getSessionAggregation(sessionId));

    // App info
    ipcMain.handle('app:info', () => ({
      version: app.getVersion(),
      platform: process.platform,
      node: process.version
    }));
  }

  /**
   * Initialize TrackerA11y services
   */
  private async initializeServices(): Promise<void> {
    try {
      // Create TrackerA11y configuration
      const config: TrackerA11yConfig = {
        platforms: ['macos'],
        syncPrecision: 'microsecond',
        realTimeMonitoring: true,
        outputFormats: ['json'],
        interactionTracking: true,
        interactionConfig: {
          enableMouse: true,
          enableKeyboard: true,
          enableTouch: false,
          enableAccessibility: true,
          privacyMode: 'detailed',
          captureLevel: 'full',
          filterSensitive: false
        }
      };

      // Initialize TrackerA11y Core
      this.state.tracker = new TrackerA11yCore(config);
      await this.state.tracker.initialize();

      // Setup event listeners
      this.setupTrackerListeners();

      console.log('✅ TrackerA11y services initialized');
      this.notifyRenderer('services:initialized', { success: true });

    } catch (error) {
      console.error('❌ Failed to initialize services:', error);
      this.notifyRenderer('services:error', { error: error?.toString() });
    }
  }

  /**
   * Setup tracker event listeners
   */
  private setupTrackerListeners(): void {
    if (!this.state.tracker) return;

    this.state.tracker.on('eventProcessed', (event: TimestampedEvent) => {
      // Store in database if connected
      if (this.state.database) {
        this.state.database.storeEvent(event);
      }

      // Send to renderer for real-time display
      this.notifyRenderer('tracker:event', event);
    });

    this.state.tracker.on('correlation', (data) => {
      if (this.state.database) {
        this.state.database.storeCorrelation(data.correlation);
      }
      this.notifyRenderer('tracker:correlation', data);
    });

    this.state.tracker.on('insight', (insight) => {
      if (this.state.database) {
        this.state.database.storeInsight(insight);
      }
      this.notifyRenderer('tracker:insight', insight);
    });

    this.state.tracker.on('error', (error) => {
      console.error('Tracker error:', error);
      this.notifyRenderer('tracker:error', { error: error.message });
    });
  }

  /**
   * Start accessibility tracking
   */
  private async startTracking(): Promise<boolean> {
    if (!this.state.tracker || this.state.isTracking) return false;

    try {
      await this.state.tracker.start();
      this.state.isTracking = true;
      
      console.log('🚀 Tracking started');
      this.notifyRenderer('tracker:started', { sessionId: this.state.currentSessionId });
      
      return true;
    } catch (error) {
      console.error('Failed to start tracking:', error);
      this.notifyRenderer('tracker:error', { error: error?.toString() });
      return false;
    }
  }

  /**
   * Stop accessibility tracking
   */
  private async stopTracking(): Promise<boolean> {
    if (!this.state.tracker || !this.state.isTracking) return false;

    try {
      await this.state.tracker.stop();
      this.state.isTracking = false;
      
      if (this.state.database && this.state.currentSessionId) {
        await this.state.database.endSession(this.state.currentSessionId);
      }
      
      console.log('⏹️ Tracking stopped');
      this.notifyRenderer('tracker:stopped', { sessionId: this.state.currentSessionId });
      
      return true;
    } catch (error) {
      console.error('Failed to stop tracking:', error);
      this.notifyRenderer('tracker:error', { error: error?.toString() });
      return false;
    }
  }

  /**
   * Connect to MongoDB database
   */
  private async connectDatabase(connectionString: string): Promise<boolean> {
    try {
      const dbConfig = {
        connectionString,
        databaseName: 'trackera11y',
        collections: {
          events: 'events',
          sessions: 'sessions',
          insights: 'insights',
          correlations: 'correlations'
        }
      };

      this.state.database = new MongoDBStore(dbConfig);
      await this.state.database.connect();
      
      console.log('✅ Database connected');
      this.notifyRenderer('database:connected');
      
      return true;
    } catch (error) {
      console.error('Database connection failed:', error);
      this.notifyRenderer('database:error', { error: error?.toString() });
      return false;
    }
  }

  /**
   * Disconnect from database
   */
  private async disconnectDatabase(): Promise<void> {
    if (this.state.database) {
      await this.state.database.disconnect();
      this.state.database = null;
      this.notifyRenderer('database:disconnected');
    }
  }

  /**
   * Create a new tracking session
   */
  private async createSession(metadata: any): Promise<string | null> {
    if (!this.state.database) return null;

    try {
      const sessionId = `session_${Date.now()}`;
      await this.state.database.startSession(sessionId, metadata);
      
      this.state.currentSessionId = sessionId;
      this.notifyRenderer('session:created', { sessionId, metadata });
      
      return sessionId;
    } catch (error) {
      console.error('Failed to create session:', error);
      this.notifyRenderer('session:error', { error: error?.toString() });
      return null;
    }
  }

  /**
   * List all sessions
   */
  private async listSessions() {
    if (!this.state.database) return [];
    
    try {
      return await this.state.database.getSessions();
    } catch (error) {
      console.error('Failed to list sessions:', error);
      return [];
    }
  }

  /**
   * Query events
   */
  private async queryEvents(filter: any) {
    if (!this.state.database) return [];
    
    try {
      return await this.state.database.queryEvents(filter);
    } catch (error) {
      console.error('Failed to query events:', error);
      return [];
    }
  }

  /**
   * Get session aggregation
   */
  private async getSessionAggregation(sessionId: string) {
    if (!this.state.database) return null;
    
    try {
      return await this.state.database.getSessionAggregation(sessionId);
    } catch (error) {
      console.error('Failed to get session aggregation:', error);
      return null;
    }
  }

  /**
   * Export session data
   */
  private async exportSessionData(sessionId: string): Promise<boolean> {
    try {
      if (!this.state.database) return false;

      const events = await this.state.database.queryEvents({ sessionId });
      const aggregation = await this.state.database.getSessionAggregation(sessionId);

      const exportData = {
        sessionId,
        exportedAt: new Date().toISOString(),
        events,
        aggregation
      };

      const { filePath } = await dialog.showSaveDialog(this.mainWindow!, {
        defaultPath: `trackera11y-session-${sessionId}.json`,
        filters: [
          { name: 'JSON Files', extensions: ['json'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      });

      if (filePath) {
        const fs = await import('fs/promises');
        await fs.writeFile(filePath, JSON.stringify(exportData, null, 2));
        
        this.notifyRenderer('session:exported', { filePath, sessionId });
        return true;
      }

      return false;
    } catch (error) {
      console.error('Failed to export session:', error);
      this.notifyRenderer('session:error', { error: error?.toString() });
      return false;
    }
  }

  /**
   * Application lifecycle methods
   */
  private async newSession(): Promise<void> {
    // TODO: Show new session dialog
  }

  private async exportSession(): Promise<void> {
    if (this.state.currentSessionId) {
      await this.exportSessionData(this.state.currentSessionId);
    }
  }

  private showAboutDialog(): void {
    dialog.showMessageBox(this.mainWindow!, {
      type: 'info',
      title: 'About TrackerA11y',
      message: 'TrackerA11y',
      detail: 'Comprehensive accessibility testing platform\\nVersion: 0.1.0\\nElectron-based macOS application'
    });
  }

  private showPreferences(): void {
    // TODO: Show preferences window
  }

  /**
   * Send message to renderer process
   */
  private notifyRenderer(channel: string, data?: any): void {
    if (this.mainWindow && !this.mainWindow.isDestroyed()) {
      this.mainWindow.webContents.send(channel, data);
    }
  }

  /**
   * Cleanup on app exit
   */
  private async cleanup(): Promise<void> {
    console.log('🧹 Cleaning up...');

    if (this.state.isTracking) {
      await this.stopTracking();
    }

    if (this.state.tracker) {
      await this.state.tracker.shutdown();
    }

    if (this.state.database) {
      await this.state.database.disconnect();
    }
  }
}

// Create the application
new TrackerA11yApp();