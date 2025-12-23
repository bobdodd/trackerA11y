import { EventEmitter } from 'events';
import {
  RecordedEvent,
  EditOperation,
  EditCommand,
  EditHistory,
  EditManagerState,
  EditOperationType
} from './types';
import * as fs from 'fs/promises';
import * as path from 'path';

class DeleteEventCommand implements EditCommand {
  private events: RecordedEvent[];
  private targetIds: string[];
  private deletedEvents: RecordedEvent[] = [];
  private operation: EditOperation;

  constructor(events: RecordedEvent[], targetIds: string[], sessionId: string) {
    this.events = events;
    this.targetIds = targetIds;
    this.deletedEvents = events.filter(e => targetIds.includes(e.id));
    this.operation = {
      id: `edit_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`,
      type: 'delete_event',
      timestamp: Date.now(),
      sessionId,
      targetEventIds: targetIds,
      affectedEvents: this.deletedEvents,
      description: `Delete ${targetIds.length} event(s)`
    };
  }

  execute(): RecordedEvent[] {
    return this.events.filter(e => !this.targetIds.includes(e.id));
  }

  undo(): RecordedEvent[] {
    const result = [...this.events];
    for (const deleted of this.deletedEvents) {
      const insertIndex = result.findIndex(e => e.timestamp > deleted.timestamp);
      if (insertIndex === -1) {
        result.push(deleted);
      } else {
        result.splice(insertIndex, 0, deleted);
      }
    }
    return result.sort((a, b) => a.timestamp - b.timestamp);
  }

  getOperation(): EditOperation {
    return this.operation;
  }
}

class DeleteRangeCommand implements EditCommand {
  private events: RecordedEvent[];
  private startTime: number;
  private endTime: number;
  private deletedEvents: RecordedEvent[] = [];
  private operation: EditOperation;

  constructor(events: RecordedEvent[], startTime: number, endTime: number, sessionId: string) {
    this.events = events;
    this.startTime = startTime;
    this.endTime = endTime;
    this.deletedEvents = events.filter(e => e.timestamp >= startTime && e.timestamp <= endTime);
    this.operation = {
      id: `edit_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`,
      type: 'delete_range',
      timestamp: Date.now(),
      sessionId,
      targetEventIds: this.deletedEvents.map(e => e.id),
      affectedEvents: this.deletedEvents,
      timeRange: { start: startTime, end: endTime },
      description: `Delete ${this.deletedEvents.length} event(s) from time range`
    };
  }

  execute(): RecordedEvent[] {
    return this.events.filter(e => e.timestamp < this.startTime || e.timestamp > this.endTime);
  }

  undo(): RecordedEvent[] {
    const result = [...this.events];
    for (const deleted of this.deletedEvents) {
      if (!result.find(e => e.id === deleted.id)) {
        const insertIndex = result.findIndex(e => e.timestamp > deleted.timestamp);
        if (insertIndex === -1) {
          result.push(deleted);
        } else {
          result.splice(insertIndex, 0, deleted);
        }
      }
    }
    return result.sort((a, b) => a.timestamp - b.timestamp);
  }

  getOperation(): EditOperation {
    return this.operation;
  }
}

export class EditManager extends EventEmitter {
  private sessionId: string;
  private outputDir: string;
  private events: RecordedEvent[] = [];
  private undoStack: EditCommand[] = [];
  private redoStack: EditCommand[] = [];
  private editHistory: EditHistory;
  private maxHistorySize: number = 100;

  constructor(sessionId: string, outputDir: string) {
    super();
    this.sessionId = sessionId;
    this.outputDir = outputDir;
    this.editHistory = {
      sessionId,
      operations: [],
      currentIndex: -1,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
  }

  async loadEvents(): Promise<RecordedEvent[]> {
    const eventsPath = path.join(this.outputDir, 'events.json');
    try {
      const data = await fs.readFile(eventsPath, 'utf-8');
      const eventLog = JSON.parse(data);
      this.events = eventLog.events || [];
      return this.events;
    } catch (error) {
      console.error('Failed to load events:', error);
      return [];
    }
  }

  setEvents(events: RecordedEvent[]): void {
    this.events = [...events];
  }

  getEvents(): RecordedEvent[] {
    return [...this.events];
  }

  deleteEvent(eventId: string): RecordedEvent[] {
    return this.deleteEvents([eventId]);
  }

  deleteEvents(eventIds: string[]): RecordedEvent[] {
    const command = new DeleteEventCommand(this.events, eventIds, this.sessionId);
    return this.executeCommand(command);
  }

  deleteTimeRange(startTime: number, endTime: number): RecordedEvent[] {
    const command = new DeleteRangeCommand(this.events, startTime, endTime, this.sessionId);
    return this.executeCommand(command);
  }

  private executeCommand(command: EditCommand): RecordedEvent[] {
    this.events = command.execute();
    this.undoStack.push(command);
    this.redoStack = [];

    if (this.undoStack.length > this.maxHistorySize) {
      this.undoStack.shift();
    }

    const operation = command.getOperation();
    this.editHistory.operations.push(operation);
    this.editHistory.currentIndex = this.editHistory.operations.length - 1;
    this.editHistory.updatedAt = Date.now();

    this.emit('edit', { operation, events: this.events, state: this.getState() });
    return this.events;
  }

  undo(): RecordedEvent[] | null {
    if (this.undoStack.length === 0) {
      return null;
    }

    const command = this.undoStack.pop()!;
    const originalEvents = command.undo();
    
    const undoCommand = this.createUndoCommand(command, originalEvents);
    this.events = originalEvents;
    this.redoStack.push(command);

    const operation = command.getOperation();
    this.editHistory.currentIndex--;
    this.editHistory.updatedAt = Date.now();

    this.emit('undo', { operation, events: this.events, state: this.getState() });
    return this.events;
  }

  redo(): RecordedEvent[] | null {
    if (this.redoStack.length === 0) {
      return null;
    }

    const command = this.redoStack.pop()!;
    this.events = command.execute();
    this.undoStack.push(command);

    const operation = command.getOperation();
    this.editHistory.currentIndex++;
    this.editHistory.updatedAt = Date.now();

    this.emit('redo', { operation, events: this.events, state: this.getState() });
    return this.events;
  }

  private createUndoCommand(originalCommand: EditCommand, restoredEvents: RecordedEvent[]): EditCommand {
    return originalCommand;
  }

  canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  getState(): EditManagerState {
    return {
      canUndo: this.canUndo(),
      canRedo: this.canRedo(),
      undoStackSize: this.undoStack.length,
      redoStackSize: this.redoStack.length,
      lastOperation: this.editHistory.operations[this.editHistory.operations.length - 1]
    };
  }

  getEditHistory(): EditHistory {
    return { ...this.editHistory };
  }

  async saveEvents(): Promise<void> {
    const eventsPath = path.join(this.outputDir, 'events.json');
    try {
      const data = await fs.readFile(eventsPath, 'utf-8');
      const eventLog = JSON.parse(data);
      eventLog.events = this.events;
      eventLog.metadata = eventLog.metadata || {};
      eventLog.metadata.lastEdited = Date.now();
      eventLog.metadata.editHistory = this.editHistory;
      await fs.writeFile(eventsPath, JSON.stringify(eventLog, null, 2));
      this.emit('saved', { sessionId: this.sessionId, eventCount: this.events.length });
    } catch (error) {
      console.error('Failed to save events:', error);
      throw error;
    }
  }

  async saveEditHistory(): Promise<void> {
    const historyPath = path.join(this.outputDir, 'edit_history.json');
    try {
      await fs.writeFile(historyPath, JSON.stringify(this.editHistory, null, 2));
    } catch (error) {
      console.error('Failed to save edit history:', error);
    }
  }

  async loadEditHistory(): Promise<EditHistory | null> {
    const historyPath = path.join(this.outputDir, 'edit_history.json');
    try {
      const data = await fs.readFile(historyPath, 'utf-8');
      this.editHistory = JSON.parse(data);
      return this.editHistory;
    } catch {
      return null;
    }
  }

  clearHistory(): void {
    this.undoStack = [];
    this.redoStack = [];
    this.editHistory = {
      sessionId: this.sessionId,
      operations: [],
      currentIndex: -1,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    this.emit('historyCleared', { sessionId: this.sessionId });
  }

  getEventsInRange(startTime: number, endTime: number): RecordedEvent[] {
    return this.events.filter(e => e.timestamp >= startTime && e.timestamp <= endTime);
  }

  getEventById(eventId: string): RecordedEvent | undefined {
    return this.events.find(e => e.id === eventId);
  }

  getDeletedEvents(): RecordedEvent[] {
    const deletedIds = new Set<string>();
    for (const op of this.editHistory.operations) {
      if (op.type === 'delete_event' || op.type === 'delete_range') {
        op.targetEventIds.forEach(id => deletedIds.add(id));
      }
    }
    const currentIds = new Set(this.events.map(e => e.id));
    return this.editHistory.operations
      .flatMap(op => op.affectedEvents)
      .filter(e => deletedIds.has(e.id) && !currentIds.has(e.id));
  }
}
