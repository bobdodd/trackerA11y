/**
 * TrackerA11y Main Application
 * React-based UI for comprehensive accessibility testing
 */

import React, { useState, useEffect } from 'react';
import {
  ThemeProvider,
  createTheme,
  CssBaseline,
  Box,
  AppBar,
  Toolbar,
  Typography,
  Container,
  Alert,
  Snackbar
} from '@mui/material';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';

// Components
import NavigationSidebar from './components/NavigationSidebar';
import Dashboard from './pages/Dashboard';
import LiveMonitoring from './pages/LiveMonitoring';
import Sessions from './pages/Sessions';
import Analytics from './pages/Analytics';
import Settings from './pages/Settings';

// Hooks
import { useElectronAPI } from './hooks/useElectronAPI';

// Theme
const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#2196f3',
    },
    secondary: {
      main: '#ff9800',
    },
    background: {
      default: '#f5f5f5',
      paper: '#ffffff',
    },
  },
  typography: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  },
  components: {
    MuiAppBar: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          boxShadow: '0 1px 3px rgba(0,0,0,0.12)',
        },
      },
    },
  },
});

interface AppState {
  isTracking: boolean;
  isConnected: boolean;
  currentSessionId: string | null;
  notification: {
    open: boolean;
    message: string;
    severity: 'success' | 'error' | 'warning' | 'info';
  };
}

const App: React.FC = () => {
  const [state, setState] = useState<AppState>({
    isTracking: false,
    isConnected: false,
    currentSessionId: null,
    notification: {
      open: false,
      message: '',
      severity: 'info'
    }
  });

  const { electronAPI, isElectronAvailable } = useElectronAPI();

  useEffect(() => {
    if (!isElectronAvailable || !electronAPI) return;

    // Set up event listeners
    const handleTrackerStarted = (data: any) => {
      setState(prev => ({
        ...prev,
        isTracking: true,
        currentSessionId: data.sessionId,
        notification: {
          open: true,
          message: 'Tracking started successfully',
          severity: 'success'
        }
      }));
    };

    const handleTrackerStopped = () => {
      setState(prev => ({
        ...prev,
        isTracking: false,
        notification: {
          open: true,
          message: 'Tracking stopped',
          severity: 'info'
        }
      }));
    };

    const handleTrackerError = (error: any) => {
      setState(prev => ({
        ...prev,
        notification: {
          open: true,
          message: `Tracker error: ${error.error}`,
          severity: 'error'
        }
      }));
    };

    const handleDatabaseConnected = () => {
      setState(prev => ({
        ...prev,
        isConnected: true,
        notification: {
          open: true,
          message: 'Database connected successfully',
          severity: 'success'
        }
      }));
    };

    const handleDatabaseDisconnected = () => {
      setState(prev => ({
        ...prev,
        isConnected: false,
        notification: {
          open: true,
          message: 'Database disconnected',
          severity: 'info'
        }
      }));
    };

    const handleDatabaseError = (error: any) => {
      setState(prev => ({
        ...prev,
        notification: {
          open: true,
          message: `Database error: ${error.error}`,
          severity: 'error'
        }
      }));
    };

    const handleServicesInitialized = () => {
      setState(prev => ({
        ...prev,
        notification: {
          open: true,
          message: 'TrackerA11y services initialized',
          severity: 'success'
        }
      }));
    };

    // Register event listeners
    electronAPI.on.trackerStarted(handleTrackerStarted);
    electronAPI.on.trackerStopped(handleTrackerStopped);
    electronAPI.on.trackerError(handleTrackerError);
    electronAPI.on.databaseConnected(handleDatabaseConnected);
    electronAPI.on.databaseDisconnected(handleDatabaseDisconnected);
    electronAPI.on.databaseError(handleDatabaseError);
    electronAPI.on.servicesInitialized(handleServicesInitialized);

    // Initialize status
    const initializeStatus = async () => {
      try {
        const [trackerStatus, databaseStatus] = await Promise.all([
          electronAPI.tracker.getStatus(),
          electronAPI.database.getStatus()
        ]);

        setState(prev => ({
          ...prev,
          isTracking: trackerStatus.isTracking,
          currentSessionId: trackerStatus.sessionId,
          isConnected: databaseStatus.connected
        }));
      } catch (error) {
        console.error('Failed to get initial status:', error);
      }
    };

    initializeStatus();

    // Cleanup event listeners
    return () => {
      electronAPI.off.trackerStarted(handleTrackerStarted);
      electronAPI.off.trackerStopped(handleTrackerStopped);
      electronAPI.off.trackerError(handleTrackerError);
      electronAPI.off.databaseConnected(handleDatabaseConnected);
      electronAPI.off.databaseDisconnected(handleDatabaseDisconnected);
      electronAPI.off.databaseError(handleDatabaseError);
      electronAPI.off.servicesInitialized(handleServicesInitialized);
    };
  }, [electronAPI, isElectronAvailable]);

  const handleCloseNotification = () => {
    setState(prev => ({
      ...prev,
      notification: {
        ...prev.notification,
        open: false
      }
    }));
  };

  if (!isElectronAvailable) {
    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <Container>
          <Alert severity="warning" sx={{ mt: 4 }}>
            This application requires Electron to run. Please run it as a desktop application.
          </Alert>
        </Container>
      </ThemeProvider>
    );
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Box sx={{ display: 'flex', height: '100vh' }}>
          {/* App Bar */}
          <AppBar
            position="fixed"
            sx={{
              zIndex: (theme) => theme.zIndex.drawer + 1,
              backgroundColor: 'background.paper',
              color: 'text.primary',
            }}
          >
            <Toolbar>
              <Typography variant="h6" noWrap component="div">
                TrackerA11y
              </Typography>
              <Box sx={{ flexGrow: 1 }} />
              <Typography variant="body2" color="text.secondary">
                {state.isTracking ? (
                  <Box component="span" sx={{ color: 'success.main' }}>
                    ● Recording
                  </Box>
                ) : (
                  '○ Idle'
                )}
                {state.isConnected && ' • Database Connected'}
              </Typography>
            </Toolbar>
          </AppBar>

          {/* Navigation Sidebar */}
          <NavigationSidebar 
            isTracking={state.isTracking}
            isConnected={state.isConnected}
            currentSessionId={state.currentSessionId}
          />

          {/* Main Content */}
          <Box
            component="main"
            sx={{
              flexGrow: 1,
              p: 3,
              ml: '240px', // Sidebar width
              mt: '64px', // AppBar height
            }}
          >
            <Routes>
              <Route path="/" element={<Navigate to="/dashboard" replace />} />
              <Route 
                path="/dashboard" 
                element={
                  <Dashboard 
                    isTracking={state.isTracking}
                    isConnected={state.isConnected}
                    currentSessionId={state.currentSessionId}
                  />
                } 
              />
              <Route 
                path="/monitor" 
                element={
                  <LiveMonitoring 
                    isTracking={state.isTracking}
                  />
                } 
              />
              <Route 
                path="/sessions" 
                element={<Sessions />} 
              />
              <Route 
                path="/analytics" 
                element={<Analytics />} 
              />
              <Route 
                path="/settings" 
                element={
                  <Settings 
                    isConnected={state.isConnected}
                  />
                } 
              />
            </Routes>
          </Box>
        </Box>

        {/* Notifications */}
        <Snackbar
          open={state.notification.open}
          autoHideDuration={6000}
          onClose={handleCloseNotification}
        >
          <Alert 
            onClose={handleCloseNotification} 
            severity={state.notification.severity}
            sx={{ width: '100%' }}
          >
            {state.notification.message}
          </Alert>
        </Snackbar>
      </Router>
    </ThemeProvider>
  );
};

export default App;