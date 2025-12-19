/**
 * TrackerA11y Electron Preload Script
 * Provides secure API bridge between renderer and main process
 */

import { contextBridge, ipcRenderer } from 'electron';

// Define TimestampedEvent interface locally since we can't import from dist during build
interface TimestampedEvent {
  id: string;
  timestamp: number;
  type: string;
  source: string;
  data: any;
}

// Define the API that will be exposed to the renderer
export interface ElectronAPI {
  // Tracker control
  tracker: {
    start(): Promise<boolean>;
    stop(): Promise<boolean>;
    getStatus(): Promise<{ isTracking: boolean; sessionId: string | null }>;
  };

  // Database operations
  database: {
    connect(connectionString: string): Promise<boolean>;
    disconnect(): Promise<void>;
    getStatus(): Promise<{ connected: boolean; currentSession: any }>;
  };

  // Session management
  session: {
    create(metadata: any): Promise<string | null>;
    list(): Promise<any[]>;
    export(sessionId: string): Promise<boolean>;
  };

  // Event queries
  events: {
    query(filter: any): Promise<TimestampedEvent[]>;
    getAggregation(sessionId: string): Promise<any>;
  };

  // Real-time event listening
  on: {
    trackerEvent(callback: (event: TimestampedEvent) => void): void;
    trackerStarted(callback: (data: any) => void): void;
    trackerStopped(callback: (data: any) => void): void;
    trackerError(callback: (error: any) => void): void;
    databaseConnected(callback: () => void): void;
    databaseDisconnected(callback: () => void): void;
    databaseError(callback: (error: any) => void): void;
    sessionCreated(callback: (data: any) => void): void;
    sessionExported(callback: (data: any) => void): void;
    servicesInitialized(callback: (data: any) => void): void;
    correlationFound(callback: (data: any) => void): void;
    insightGenerated(callback: (insight: any) => void): void;
  };

  // Remove event listeners
  off: {
    trackerEvent(callback: (event: TimestampedEvent) => void): void;
    trackerStarted(callback: (data: any) => void): void;
    trackerStopped(callback: (data: any) => void): void;
    trackerError(callback: (error: any) => void): void;
    databaseConnected(callback: () => void): void;
    databaseDisconnected(callback: () => void): void;
    databaseError(callback: (error: any) => void): void;
    sessionCreated(callback: (data: any) => void): void;
    sessionExported(callback: (data: any) => void): void;
    servicesInitialized(callback: (data: any) => void): void;
    correlationFound(callback: (data: any) => void): void;
    insightGenerated(callback: (insight: any) => void): void;
  };

  // App info
  app: {
    getInfo(): Promise<{ version: string; platform: string; node: string }>;
  };
}

// Create the API object
const electronAPI: ElectronAPI = {
  // Tracker control
  tracker: {
    start: () => ipcRenderer.invoke('tracker:start'),
    stop: () => ipcRenderer.invoke('tracker:stop'),
    getStatus: () => ipcRenderer.invoke('tracker:status')
  },

  // Database operations
  database: {
    connect: (connectionString: string) => ipcRenderer.invoke('database:connect', connectionString),
    disconnect: () => ipcRenderer.invoke('database:disconnect'),
    getStatus: () => ipcRenderer.invoke('database:status')
  },

  // Session management
  session: {
    create: (metadata: any) => ipcRenderer.invoke('session:create', metadata),
    list: () => ipcRenderer.invoke('session:list'),
    export: (sessionId: string) => ipcRenderer.invoke('session:export', sessionId)
  },

  // Event queries
  events: {
    query: (filter: any) => ipcRenderer.invoke('events:query', filter),
    getAggregation: (sessionId: string) => ipcRenderer.invoke('events:aggregation', sessionId)
  },

  // Real-time event listening
  on: {
    trackerEvent: (callback) => ipcRenderer.on('tracker:event', (_, data) => callback(data)),
    trackerStarted: (callback) => ipcRenderer.on('tracker:started', (_, data) => callback(data)),
    trackerStopped: (callback) => ipcRenderer.on('tracker:stopped', (_, data) => callback(data)),
    trackerError: (callback) => ipcRenderer.on('tracker:error', (_, error) => callback(error)),
    databaseConnected: (callback) => ipcRenderer.on('database:connected', () => callback()),
    databaseDisconnected: (callback) => ipcRenderer.on('database:disconnected', () => callback()),
    databaseError: (callback) => ipcRenderer.on('database:error', (_, error) => callback(error)),
    sessionCreated: (callback) => ipcRenderer.on('session:created', (_, data) => callback(data)),
    sessionExported: (callback) => ipcRenderer.on('session:exported', (_, data) => callback(data)),
    servicesInitialized: (callback) => ipcRenderer.on('services:initialized', (_, data) => callback(data)),
    correlationFound: (callback) => ipcRenderer.on('tracker:correlation', (_, data) => callback(data)),
    insightGenerated: (callback) => ipcRenderer.on('tracker:insight', (_, insight) => callback(insight))
  },

  // Remove event listeners
  off: {
    trackerEvent: (callback) => ipcRenderer.removeListener('tracker:event', (_, data) => callback(data)),
    trackerStarted: (callback) => ipcRenderer.removeListener('tracker:started', (_, data) => callback(data)),
    trackerStopped: (callback) => ipcRenderer.removeListener('tracker:stopped', (_, data) => callback(data)),
    trackerError: (callback) => ipcRenderer.removeListener('tracker:error', (_, error) => callback(error)),
    databaseConnected: (callback) => ipcRenderer.removeListener('database:connected', () => callback()),
    databaseDisconnected: (callback) => ipcRenderer.removeListener('database:disconnected', () => callback()),
    databaseError: (callback) => ipcRenderer.removeListener('database:error', (_, error) => callback(error)),
    sessionCreated: (callback) => ipcRenderer.removeListener('session:created', (_, data) => callback(data)),
    sessionExported: (callback) => ipcRenderer.removeListener('session:exported', (_, data) => callback(data)),
    servicesInitialized: (callback) => ipcRenderer.removeListener('services:initialized', (_, data) => callback(data)),
    correlationFound: (callback) => ipcRenderer.removeListener('tracker:correlation', (_, data) => callback(data)),
    insightGenerated: (callback) => ipcRenderer.removeListener('tracker:insight', (_, insight) => callback(insight))
  },

  // App info
  app: {
    getInfo: () => ipcRenderer.invoke('app:info')
  }
};

// Expose the API to the renderer process
contextBridge.exposeInMainWorld('electronAPI', electronAPI);

// Type declaration for the global window object
declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}