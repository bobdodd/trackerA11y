/**
 * MongoDB Storage for TrackerA11y Events
 * Provides high-performance storage and querying for accessibility tracking data
 */

import { MongoClient, Db, Collection, IndexDescription } from 'mongodb';
import { EventEmitter } from 'events';
import { 
  TimestampedEvent, 
  InteractionEvent, 
  FocusEvent, 
  AudioEvent,
  AccessibilityInsight,
  CorrelatedEvent
} from '@/types';

export interface MongoDBConfig {
  connectionString: string;
  databaseName: string;
  collections: {
    events: string;
    sessions: string;
    insights: string;
    correlations: string;
  };
}

export interface TrackingSession {
  _id?: string;
  sessionId: string;
  startTime: number;
  endTime?: number;
  platform: string;
  userId?: string;
  metadata: {
    appVersion: string;
    platform: string;
    config: any;
    [key: string]: any;
  };
  stats: {
    totalEvents: number;
    totalInteractions: number;
    totalFocusChanges: number;
    duration?: number;
  };
  status: 'active' | 'completed' | 'error';
}

export interface EventFilter {
  sessionId?: string;
  source?: string[];
  interactionType?: string[];
  startTime?: number;
  endTime?: number;
  limit?: number;
  skip?: number;
}

export interface EventAggregation {
  sessionId: string;
  totalEvents: number;
  eventsBySource: Record<string, number>;
  eventsByType: Record<string, number>;
  timeRange: {
    start: number;
    end: number;
    duration: number;
  };
  topApplications: Array<{
    name: string;
    focusTime: number;
    interactions: number;
  }>;
  interactionStats: {
    clicks: number;
    keystrokes: number;
    scrolls: number;
    hovers: number;
    drags: number;
  };
}

export class MongoDBStore extends EventEmitter {
  private client: MongoClient | null = null;
  private db: Db | null = null;
  private collections: {
    events: Collection<TimestampedEvent>;
    sessions: Collection<TrackingSession>;
    insights: Collection<AccessibilityInsight>;
    correlations: Collection<CorrelatedEvent>;
  } | null = null;

  private config: MongoDBConfig;
  private isConnected = false;
  private currentSession: TrackingSession | null = null;

  constructor(config: MongoDBConfig) {
    super();
    this.config = config;
  }

  /**
   * Connect to MongoDB and initialize collections
   */
  async connect(): Promise<void> {
    try {
      console.log('🔌 Connecting to MongoDB...');
      
      this.client = new MongoClient(this.config.connectionString);
      await this.client.connect();
      
      this.db = this.client.db(this.config.databaseName);
      
      // Initialize collections
      this.collections = {
        events: this.db.collection(this.config.collections.events),
        sessions: this.db.collection(this.config.collections.sessions),
        insights: this.db.collection(this.config.collections.insights),
        correlations: this.db.collection(this.config.collections.correlations)
      };

      // Create indexes for performance
      await this.createIndexes();
      
      this.isConnected = true;
      this.emit('connected');
      
      console.log('✅ MongoDB connected successfully');
      
    } catch (error) {
      console.error('❌ MongoDB connection failed:', error);
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Create optimized indexes for query performance
   */
  private async createIndexes(): Promise<void> {
    if (!this.collections) return;

    const eventIndexes: IndexDescription[] = [
      { key: { sessionId: 1, timestamp: 1 } },
      { key: { source: 1, timestamp: 1 } },
      { key: { 'data.interactionType': 1, timestamp: 1 } },
      { key: { timestamp: 1 } },
      { key: { sessionId: 1, source: 1, timestamp: 1 } }
    ];

    const sessionIndexes: IndexDescription[] = [
      { key: { sessionId: 1 }, unique: true },
      { key: { startTime: 1 } },
      { key: { status: 1, startTime: 1 } },
      { key: { userId: 1, startTime: 1 } }
    ];

    await Promise.all([
      this.collections.events.createIndexes(eventIndexes),
      this.collections.sessions.createIndexes(sessionIndexes),
      this.collections.insights.createIndex({ sessionId: 1, timestamp: 1 }),
      this.collections.correlations.createIndex({ sessionId: 1, timestamp: 1 })
    ]);

    console.log('📊 Database indexes created');
  }

  /**
   * Start a new tracking session
   */
  async startSession(sessionId: string, metadata: any): Promise<TrackingSession> {
    if (!this.collections) throw new Error('Database not connected');

    const session: TrackingSession = {
      sessionId,
      startTime: Date.now() * 1000, // microseconds
      platform: process.platform,
      metadata: {
        appVersion: '0.1.0',
        platform: process.platform,
        ...metadata
      },
      stats: {
        totalEvents: 0,
        totalInteractions: 0,
        totalFocusChanges: 0
      },
      status: 'active'
    };

    await this.collections.sessions.insertOne(session);
    this.currentSession = session;
    
    console.log(`📝 Started tracking session: ${sessionId}`);
    this.emit('sessionStarted', session);
    
    return session;
  }

  /**
   * End the current tracking session
   */
  async endSession(sessionId?: string): Promise<void> {
    if (!this.collections || !this.currentSession) return;

    const targetSessionId = sessionId || this.currentSession.sessionId;
    const endTime = Date.now() * 1000;

    // Calculate final stats
    const stats = await this.getSessionStats(targetSessionId);
    
    await this.collections.sessions.updateOne(
      { sessionId: targetSessionId },
      {
        $set: {
          endTime,
          status: 'completed',
          'stats.duration': endTime - (this.currentSession.startTime || 0),
          stats
        }
      }
    );

    console.log(`✅ Ended tracking session: ${targetSessionId}`);
    this.emit('sessionEnded', targetSessionId);
    
    if (this.currentSession.sessionId === targetSessionId) {
      this.currentSession = null;
    }
  }

  /**
   * Store a single event
   */
  async storeEvent(event: TimestampedEvent): Promise<void> {
    if (!this.collections || !this.currentSession) return;

    try {
      // Add session context
      const eventWithSession = {
        ...event,
        sessionId: this.currentSession.sessionId
      };

      await this.collections.events.insertOne(eventWithSession);

      // Update session stats
      await this.updateSessionStats(event);
      
      this.emit('eventStored', event);

    } catch (error) {
      console.error('Error storing event:', error);
      this.emit('error', error);
    }
  }

  /**
   * Store multiple events in batch
   */
  async storeEventBatch(events: TimestampedEvent[]): Promise<void> {
    if (!this.collections || !this.currentSession || events.length === 0) return;

    try {
      // Add session context to all events
      const eventsWithSession = events.map(event => ({
        ...event,
        sessionId: this.currentSession!.sessionId
      }));

      await this.collections.events.insertMany(eventsWithSession);

      // Update session stats
      for (const event of events) {
        await this.updateSessionStats(event);
      }
      
      console.log(`📦 Stored batch of ${events.length} events`);
      this.emit('eventBatchStored', events);

    } catch (error) {
      console.error('Error storing event batch:', error);
      this.emit('error', error);
    }
  }

  /**
   * Query events with filtering and pagination
   */
  async queryEvents(filter: EventFilter = {}): Promise<TimestampedEvent[]> {
    if (!this.collections) throw new Error('Database not connected');

    const query: any = {};
    
    if (filter.sessionId) query.sessionId = filter.sessionId;
    if (filter.source) query.source = { $in: filter.source };
    if (filter.interactionType) query['data.interactionType'] = { $in: filter.interactionType };
    if (filter.startTime || filter.endTime) {
      query.timestamp = {};
      if (filter.startTime) query.timestamp.$gte = filter.startTime;
      if (filter.endTime) query.timestamp.$lte = filter.endTime;
    }

    const cursor = this.collections.events
      .find(query)
      .sort({ timestamp: 1 });

    if (filter.skip) cursor.skip(filter.skip);
    if (filter.limit) cursor.limit(filter.limit);

    return await cursor.toArray();
  }

  /**
   * Get session aggregation and analytics
   */
  async getSessionAggregation(sessionId: string): Promise<EventAggregation | null> {
    if (!this.collections) throw new Error('Database not connected');

    const pipeline = [
      { $match: { sessionId } },
      {
        $group: {
          _id: null,
          totalEvents: { $sum: 1 },
          eventsBySource: {
            $push: '$source'
          },
          eventsByType: {
            $push: '$data.interactionType'
          },
          minTimestamp: { $min: '$timestamp' },
          maxTimestamp: { $max: '$timestamp' },
          focusEvents: {
            $push: {
              $cond: [
                { $eq: ['$source', 'focus'] },
                '$data.applicationName',
                null
              ]
            }
          },
          interactions: {
            $push: {
              $cond: [
                { $eq: ['$source', 'interaction'] },
                '$data.interactionType',
                null
              ]
            }
          }
        }
      }
    ];

    const result = await this.collections.events.aggregate(pipeline).toArray();
    
    if (result.length === 0) return null;

    const data = result[0];
    
    // Process aggregated data
    const eventsBySource: Record<string, number> = {};
    data.eventsBySource.forEach((source: string) => {
      eventsBySource[source] = (eventsBySource[source] || 0) + 1;
    });

    const eventsByType: Record<string, number> = {};
    data.eventsByType.filter(Boolean).forEach((type: string) => {
      eventsByType[type] = (eventsByType[type] || 0) + 1;
    });

    const interactions = data.interactions.filter(Boolean);
    
    return {
      sessionId,
      totalEvents: data.totalEvents,
      eventsBySource,
      eventsByType,
      timeRange: {
        start: data.minTimestamp,
        end: data.maxTimestamp,
        duration: data.maxTimestamp - data.minTimestamp
      },
      topApplications: [], // Would need more complex aggregation
      interactionStats: {
        clicks: interactions.filter((t: string) => t === 'click').length,
        keystrokes: interactions.filter((t: string) => t === 'key').length,
        scrolls: interactions.filter((t: string) => t === 'scroll').length,
        hovers: interactions.filter((t: string) => t === 'hover').length,
        drags: interactions.filter((t: string) => t === 'drag').length
      }
    };
  }

  /**
   * Get all sessions with basic info
   */
  async getSessions(limit = 50): Promise<TrackingSession[]> {
    if (!this.collections) throw new Error('Database not connected');

    return await this.collections.sessions
      .find({})
      .sort({ startTime: -1 })
      .limit(limit)
      .toArray();
  }

  /**
   * Store accessibility insight
   */
  async storeInsight(insight: AccessibilityInsight): Promise<void> {
    if (!this.collections || !this.currentSession) return;

    const insightWithSession = {
      ...insight,
      sessionId: this.currentSession.sessionId
    };

    await this.collections.insights.insertOne(insightWithSession);
    this.emit('insightStored', insight);
  }

  /**
   * Store correlation
   */
  async storeCorrelation(correlation: CorrelatedEvent): Promise<void> {
    if (!this.collections || !this.currentSession) return;

    const correlationWithSession = {
      ...correlation,
      sessionId: this.currentSession.sessionId
    };

    await this.collections.correlations.insertOne(correlationWithSession);
    this.emit('correlationStored', correlation);
  }

  private async updateSessionStats(event: TimestampedEvent): Promise<void> {
    if (!this.collections || !this.currentSession) return;

    const updates: any = {
      $inc: { 'stats.totalEvents': 1 }
    };

    if (event.source === 'interaction') {
      updates.$inc['stats.totalInteractions'] = 1;
    } else if (event.source === 'focus') {
      updates.$inc['stats.totalFocusChanges'] = 1;
    }

    await this.collections.sessions.updateOne(
      { sessionId: this.currentSession.sessionId },
      updates
    );
  }

  private async getSessionStats(sessionId: string): Promise<any> {
    if (!this.collections) return {};

    const result = await this.collections.events.aggregate([
      { $match: { sessionId } },
      {
        $group: {
          _id: null,
          totalEvents: { $sum: 1 },
          totalInteractions: {
            $sum: { $cond: [{ $eq: ['$source', 'interaction'] }, 1, 0] }
          },
          totalFocusChanges: {
            $sum: { $cond: [{ $eq: ['$source', 'focus'] }, 1, 0] }
          }
        }
      }
    ]).toArray();

    return result.length > 0 ? result[0] : {};
  }

  /**
   * Disconnect from MongoDB
   */
  async disconnect(): Promise<void> {
    if (this.currentSession) {
      await this.endSession();
    }

    if (this.client) {
      await this.client.close();
      this.client = null;
      this.db = null;
      this.collections = null;
      this.isConnected = false;
      
      console.log('🔌 MongoDB disconnected');
      this.emit('disconnected');
    }
  }

  /**
   * Health check
   */
  async healthCheck(): Promise<boolean> {
    if (!this.client) return false;
    
    try {
      await this.client.db('admin').command({ ping: 1 });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get current session info
   */
  getCurrentSession(): TrackingSession | null {
    return this.currentSession;
  }

  /**
   * Check if connected
   */
  isConnectedToDatabase(): boolean {
    return this.isConnected;
  }
}