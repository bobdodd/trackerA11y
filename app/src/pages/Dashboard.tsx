/**
 * Dashboard - Main overview of TrackerA11y status and controls
 */

import React, { useState } from 'react';
import {
  Grid,
  Paper,
  Typography,
  Box,
  Button,
  Card,
  CardContent,
  CardActions,
  Chip,
  Alert,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions
} from '@mui/material';
import {
  PlayArrow as PlayIcon,
  Stop as StopIcon,
  Storage as DatabaseIcon,
  Analytics as AnalyticsIcon,
  Visibility as MonitorIcon
} from '@mui/icons-material';

import { useElectronAPI } from '../hooks/useElectronAPI';

interface DashboardProps {
  isTracking: boolean;
  isConnected: boolean;
  currentSessionId: string | null;
}

const Dashboard: React.FC<DashboardProps> = ({ 
  isTracking, 
  isConnected, 
  currentSessionId 
}) => {
  const { electronAPI } = useElectronAPI();
  const [isStarting, setIsStarting] = useState(false);
  const [isStopping, setIsStopping] = useState(false);
  const [sessionDialog, setSessionDialog] = useState(false);
  const [sessionName, setSessionName] = useState('');
  const [sessionDescription, setSessionDescription] = useState('');

  const handleStartTracking = async () => {
    if (!isConnected) {
      alert('Please connect to database first');
      return;
    }

    setSessionDialog(true);
  };

  const handleCreateSession = async () => {
    if (!sessionName.trim()) return;

    setIsStarting(true);
    try {
      // Create session
      const sessionId = await electronAPI?.session.create({
        name: sessionName,
        description: sessionDescription,
        createdAt: new Date().toISOString(),
        platform: 'macOS'
      });

      if (sessionId) {
        // Start tracking
        await electronAPI?.tracker.start();
      }
    } catch (error) {
      console.error('Failed to start session:', error);
    } finally {
      setIsStarting(false);
      setSessionDialog(false);
      setSessionName('');
      setSessionDescription('');
    }
  };

  const handleStopTracking = async () => {
    setIsStopping(true);
    try {
      await electronAPI?.tracker.stop();
    } catch (error) {
      console.error('Failed to stop tracking:', error);
    } finally {
      setIsStopping(false);
    }
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>

      <Grid container spacing={3}>
        {/* Status Cards */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" mb={1}>
                <MonitorIcon color={isTracking ? 'success' : 'disabled'} />
                <Typography variant="h6" sx={{ ml: 1 }}>
                  Tracking Status
                </Typography>
              </Box>
              <Chip
                label={isTracking ? 'Recording' : 'Stopped'}
                color={isTracking ? 'success' : 'default'}
                variant="outlined"
              />
              {currentSessionId && (
                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                  Session: {currentSessionId}
                </Typography>
              )}
            </CardContent>
            <CardActions>
              {!isTracking ? (
                <Button
                  variant="contained"
                  startIcon={<PlayIcon />}
                  onClick={handleStartTracking}
                  disabled={isStarting || !isConnected}
                  color="success"
                >
                  Start Recording
                </Button>
              ) : (
                <Button
                  variant="contained"
                  startIcon={<StopIcon />}
                  onClick={handleStopTracking}
                  disabled={isStopping}
                  color="error"
                >
                  Stop Recording
                </Button>
              )}
            </CardActions>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" mb={1}>
                <DatabaseIcon color={isConnected ? 'success' : 'disabled'} />
                <Typography variant="h6" sx={{ ml: 1 }}>
                  Database Status
                </Typography>
              </Box>
              <Chip
                label={isConnected ? 'Connected' : 'Disconnected'}
                color={isConnected ? 'success' : 'error'}
                variant="outlined"
              />
            </CardContent>
            <CardActions>
              <Button size="small" href="/settings">
                Configure
              </Button>
            </CardActions>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" mb={1}>
                <AnalyticsIcon color="primary" />
                <Typography variant="h6" sx={{ ml: 1 }}>
                  Analytics
                </Typography>
              </Box>
              <Typography variant="body2" color="text.secondary">
                View session analytics and insights
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small" href="/analytics">
                View Analytics
              </Button>
            </CardActions>
          </Card>
        </Grid>

        {/* Instructions */}
        <Grid item xs={12}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Getting Started
            </Typography>
            
            {!isConnected && (
              <Alert severity="warning" sx={{ mb: 2 }}>
                Connect to MongoDB database in Settings to start recording sessions.
              </Alert>
            )}

            <Typography variant="body1" paragraph>
              TrackerA11y captures comprehensive accessibility data including:
            </Typography>

            <Box component="ul" sx={{ pl: 2 }}>
              <li>👁️ Focus tracking - Monitor which applications and elements have focus</li>
              <li>🖱️ Mouse interactions - All buttons, modifier keys, and coordinates</li>
              <li>⌨️ Keyboard input - Key presses and combinations</li>
              <li>🚢 Dock interactions - Native macOS dock detection</li>
              <li>🌐 Browser elements - Real-time DOM element identification</li>
              <li>🫧 Hover behavior - Dwell time and movement analysis</li>
            </Box>

            <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
              All data is stored with microsecond precision for detailed analysis and correlation.
            </Typography>
          </Paper>
        </Grid>
      </Grid>

      {/* Session Creation Dialog */}
      <Dialog open={sessionDialog} onClose={() => setSessionDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create New Session</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Session Name"
            fullWidth
            variant="outlined"
            value={sessionName}
            onChange={(e) => setSessionName(e.target.value)}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            label="Description (optional)"
            fullWidth
            multiline
            rows={3}
            variant="outlined"
            value={sessionDescription}
            onChange={(e) => setSessionDescription(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSessionDialog(false)}>Cancel</Button>
          <Button 
            onClick={handleCreateSession} 
            disabled={!sessionName.trim() || isStarting}
            variant="contained"
          >
            Create & Start Recording
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Dashboard;